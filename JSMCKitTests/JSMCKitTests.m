// JSMCKit
// Improved SMC library
// Copyright (C) 2018 jackw01. Released under the MIT license.

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <JSMCKit/JSMCKit.h>

@interface JSMCKitTests : XCTestCase

@end

@implementation JSMCKitTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)test {

    SMC *smc = [SMC smc];

    NSLog(@"Ambient light (lux): %d", [smc ambientLightInLux]);

    // Get number of fans
    unsigned int numberOfFans = [smc numberOfFans];
    NSLog(@"Fans: %d", numberOfFans);

    // Fans
    for (int f = 0; f < numberOfFans; f++) {
        NSLog(@"Fan %d speed: %f", f, [smc speedOfFan:f]);
        NSLog(@"Fan %d min speed: %f", f, [smc minimumSpeedOfFan:f]);
        NSLog(@"Fan %d max speed: %f", f, [smc maximumSpeedOfFan:f]);
    }

    NSLog(@"Max CPU temp: %f", [smc cpuTemperatureInDegreesCelsius]);

    // Temps
    for (NSString *key in smc.workingTempKeys) {
        NSLog(@"%@ %@: %f", key, [smc humanReadableNameForKey:key], [smc readNumberForKey:key]);
    }

    // Voltages
    for (NSString *key in smc.workingVoltageKeys) {
        NSLog(@"%@ %@: %f", key, [smc humanReadableNameForKey:key], [smc readNumberForKey:key]);
    }

    // Current
    for (NSString *key in smc.workingCurrentKeys) {
        NSLog(@"%@ %@: %f", key, [smc humanReadableNameForKey:key], [smc readNumberForKey:key]);
    }

    // Power
    for (NSString *key in smc.workingPowerKeys) {
        NSLog(@"%@ %@: %f", key, [smc humanReadableNameForKey:key], [smc readNumberForKey:key]);
    }
}

@end
