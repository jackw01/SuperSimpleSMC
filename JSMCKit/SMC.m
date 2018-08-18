// SuperSimpleSMC
// Improved SMC library
// Copyright (C) 2018 jackw01. Released under the MIT license.

#import "SMC.h"

// SMC selector for IOKit
static const uint32_t ioSelectorSMC = 2;

// SMC commands
static const char smcCommandReadBytes = 5;
static const char smcCommandWriteBytes = 6;
static const char smcCommandReadIndex = 8;
static const char smcCommandKeyInfo = 9;
static const char smcCommandReadPLimit = 11;
static const char smcCommandReadVersion = 12;

// FourCC type for keys and 32 char type for values
typedef char SMCFourCC_t[5];
typedef char SMCValue_t[32];

// Internal datatypes: see original SMC tool by devnull
typedef struct {
    char major;
    char minor;
    char build;
    char reserved[1];
    uint16_t release;
} SMCKeyData_version_t;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    char dataAttributes;
} SMCKeyData_keyInfo_t;

typedef struct {
    uint32_t key;
    SMCKeyData_version_t version;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    char result;
    char status;
    char data8;
    uint32_t data32;
    SMCValue_t bytes;
} SMCKeyData_t;

// Class begins here
@interface SMC()
@property io_connect_t connection; // The IO service for the SMC
@property (strong) NSDictionary *humanReadableNamesForKeys;
@end

@implementation SMC

+ (instancetype)smc {
    static dispatch_once_t once;
    static id smc;
    dispatch_once(&once, ^{
        smc = [[self alloc] init];
    });
    return smc;
}

- (id)init {
    if (self = [super init]) {
        mach_port_t masterPort;
        io_iterator_t iterator;

        // Open IOKit master port
        kern_return_t result = IOMasterPort(MACH_PORT_NULL, &masterPort);

        // Find the AppleSMC IOService
        CFMutableDictionaryRef matchingDictionary = IOServiceMatching("AppleSMC");
        result = IOServiceGetMatchingServices(masterPort, matchingDictionary, &iterator);
        if (result != kIOReturnSuccess) NSLog(@"Unable to connect: Find service failed with %08x", result);

        // Assume that device has only one SMC and take first item
        io_object_t device = IOIteratorNext(iterator);
        IOObjectRelease(iterator);
        if (device == 0) NSLog(@"Unable to connect: SMC not found");

        // Connect to the SMC
        io_connect_t connection = self.connection;
        result = IOServiceOpen(device, mach_task_self(), 0, &connection);
        self.connection = connection;
        IOObjectRelease(device);
        if (result != kIOReturnSuccess) NSLog(@"Unable to connect: Open service failed with %08x", result);

        // Load keys.json and get key lists
        NSString *path  = [[NSBundle bundleForClass:[self class]] pathForResource:@"keys" ofType:@"json"];
        NSString *jsonString = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *smcKeys = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];

        self.allTempKeys = [[smcKeys objectForKey:@"temperature"] allKeys];
        self.allVoltageKeys = [[smcKeys objectForKey:@"voltage"] allKeys];
        self.allCurrentKeys = [[smcKeys objectForKey:@"current"] allKeys];
        self.allPowerKeys = [[smcKeys objectForKey:@"power"] allKeys];

        NSMutableDictionary *names = [[NSMutableDictionary alloc] init];
        [names addEntriesFromDictionary:[smcKeys objectForKey:@"temperature"]];
        [names addEntriesFromDictionary:[smcKeys objectForKey:@"voltage"]];
        [names addEntriesFromDictionary:[smcKeys objectForKey:@"current"]];
        [names addEntriesFromDictionary:[smcKeys objectForKey:@"power"]];
        self.humanReadableNamesForKeys = [NSDictionary dictionaryWithDictionary:names];

        // See which keys work and add them to working keys arrays
        NSMutableArray *workingKeysMutable;

        workingKeysMutable = [[NSMutableArray alloc] init];
        for (id key in self.allTempKeys) {
            float value = [self readNumberForKey: key];
            if (value != 0) [workingKeysMutable addObject:key];
        }
        self.workingTempKeys = [[NSArray alloc] initWithArray:workingKeysMutable];

        workingKeysMutable = [[NSMutableArray alloc] init];
        for (id key in self.allVoltageKeys) {
            float value = [self readNumberForKey: key];
            if (value != 0) [workingKeysMutable addObject:key];
        }
        self.workingVoltageKeys = [[NSArray alloc] initWithArray:workingKeysMutable];

        workingKeysMutable = [[NSMutableArray alloc] init];
        for (id key in self.allCurrentKeys) {
            float value = [self readNumberForKey: key];
            if (value != 0) [workingKeysMutable addObject:key];
        }
        self.workingCurrentKeys = [[NSArray alloc] initWithArray:workingKeysMutable];

        workingKeysMutable = [[NSMutableArray alloc] init];
        for (id key in self.allPowerKeys) {
            float value = [self readNumberForKey: key];
            if (value != 0) [workingKeysMutable addObject:key];
        }
        self.workingPowerKeys = [[NSArray alloc] initWithArray:workingKeysMutable];
    }
    return self;
}

- (NSString *)humanReadableNameForKey:(NSString *)key {
    return [self.humanReadableNamesForKeys objectForKey:key];
}

- (float)readNumberForKey:(NSString *)key {
    SMCKeyData_t inData;
    SMCKeyData_t outData;
    size_t structSize = sizeof(SMCKeyData_t);

    // Clear input and output structs - this is necessary
    memset(&inData, 0, structSize);
    memset(&outData, 0, structSize);

    // Send key as uint32_t and the command type
    for (int i = 0; i < 4; i++) inData.key += [key UTF8String][i] << (4 - 1 - i) * 8;
    inData.data8 = smcCommandKeyInfo;

    // Call the SMC to get key info
    kern_return_t result = IOConnectCallStructMethod(self.connection, ioSelectorSMC,
                                                     &inData, structSize,
                                                     &outData, &structSize);

    if (result != kIOReturnSuccess) return 0;

    // Get data size and type
    uint32_t size = outData.keyInfo.dataSize;
    SMCFourCC_t type;
    sprintf(type, "%c%c%c%c", (unsigned int) outData.keyInfo.dataType >> 24,
                              (unsigned int) outData.keyInfo.dataType >> 16,
                              (unsigned int) outData.keyInfo.dataType >> 8,
                              (unsigned int) outData.keyInfo.dataType);

    inData.keyInfo.dataSize = size;
    inData.data8 = smcCommandReadBytes;

    // Call the SMC to read the key
    result = IOConnectCallStructMethod(self.connection, ioSelectorSMC,
                                       &inData, structSize,
                                       &outData, &structSize);

    if (result != kIOReturnSuccess) return 0;

    if (strcmp(type, "ui8 ") == 0 || strcmp(type, "ui16") == 0 || strcmp(type, "ui32") == 0) {
        uint32_t total = 0;
        for (int i = 0; i < size; i++) total += (unsigned char)(outData.bytes[i] << (size - 1 - i) * 8);
        return (float)total;
    } else if (strcmp(type, "fp1f") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) / 32768.0;
    else if (strcmp(type, "fp4c") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) / 4096.0;
    else if (strcmp(type, "fp5b") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) / 2048.0;
    else if (strcmp(type, "fp6a") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) / 1024.0;
    else if (strcmp(type, "fp79") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) / 512.0;
    else if (strcmp(type, "fp88") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) / 256.0;
    else if (strcmp(type, "fpa6") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) / 64.0;
    else if (strcmp(type, "fpc4") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) / 16.0;
    else if (strcmp(type, "fpe2") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) / 4.0;
    else if (strcmp(type, "sp1e") == 0 && size == 2) return ((int16_t)ntohs(*(uint16_t *)outData.bytes)) / 16384.0;
    else if (strcmp(type, "sp3c") == 0 && size == 2) return ((int16_t)ntohs(*(uint16_t *)outData.bytes)) / 4096.0;
    else if (strcmp(type, "sp4b") == 0 && size == 2) return ((int16_t)ntohs(*(uint16_t *)outData.bytes)) / 2048.0;
    else if (strcmp(type, "sp5a") == 0 && size == 2) return ((int16_t)ntohs(*(uint16_t *)outData.bytes)) / 1024.0;
    else if (strcmp(type, "sp69") == 0 && size == 2) return ((int16_t)ntohs(*(uint16_t *)outData.bytes)) / 512.0;
    else if (strcmp(type, "sp78") == 0 && size == 2) return ((int16_t)ntohs(*(uint16_t *)outData.bytes)) / 256.0;
    else if (strcmp(type, "sp87") == 0 && size == 2) return ((int16_t)ntohs(*(uint16_t *)outData.bytes)) / 128.0;
    else if (strcmp(type, "sp96") == 0 && size == 2) return ((int16_t)ntohs(*(uint16_t *)outData.bytes)) / 64.0;
    else if (strcmp(type, "spb4") == 0 && size == 2) return ((int16_t)ntohs(*(uint16_t *)outData.bytes)) / 16.0;
    else if (strcmp(type, "spf0") == 0 && size == 2) return (float)ntohs(*(uint16_t *)outData.bytes);
    else if (strcmp(type, "si16") == 0 && size == 2) return (float)ntohs(*(int16_t *)outData.bytes);
    else if (strcmp(type, "si8 ") == 0 && size == 1) return (float) *outData.bytes;
    else if (strcmp(type, "{pwm") == 0 && size == 2) return ntohs(*(uint16_t *)outData.bytes) * 100 / 65536.0;
    else return 0;
}

- (unsigned int)ambientLightInLux {
    return [self readNumberForKey:@"ALSL"];
}

- (unsigned int)numberOfFans {
    return [self readNumberForKey:@"FNum"];
}

- (float)speedOfFan:(NSUInteger)fan {
    return [self readNumberForKey:[NSString stringWithFormat:@"F%luAc", (unsigned long)fan]];
}

- (float)minimumSpeedOfFan:(NSUInteger)fan {
    return [self readNumberForKey:[NSString stringWithFormat:@"F%luMn", (unsigned long)fan]];
}

- (float)maximumSpeedOfFan:(NSUInteger)fan {
    return [self readNumberForKey:[NSString stringWithFormat:@"F%luMx", (unsigned long)fan]];
}

// Get CPU temperature in degrees celsius
- (float)cpuTemperatureInDegreesCelsius {
    NSArray *keys = @[@"TCXC", @"TCXc", @"TC0P", @"TC0H", @"TC0D", @"TC0E", @"TC0F", @"TC1C", @"TC2C", @"TC3C", @"TC4C", @"TC5C", @"TC6C", @"TC7C", @"TC8C", @"TCAH", @"TCAD", @"TC1P", @"TC1H", @"TC1D", @"TC1E", @"TC1F", @"TCBH", @"TCBD"];
    float maximum = 0;
    for (int i = 0; i < keys.count; i++) {
        float temp = [self readNumberForKey:keys[i]];
        if (temp > maximum) maximum = temp;
    }
    return maximum;
}

// Close connection to SMC service on dealloc
- (void)dealloc {
    IOServiceClose(self.connection);
}

@end
