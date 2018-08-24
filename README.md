# SuperSimpleSMC
Better SMC framework for macOS with support for more sensors including voltage/current/power

## What is this for?
This framework allows you to read data from system sensors in all Intel Macs through the System Management Controller.

## Features
* Easy to use
* No dependencies and small size
* Human-readable names for more keys than (most? all?) other frameworks and system monitoring applications

## Code example
```objective-c
// Import
#import <JSMCKit/JSMCKit.h>

// Get shared instance
SMC *smc = [SMC smc];

// Get ambient light level
NSLog(@"Ambient light (lux): %d", [smc ambientLightInLux]);

// Get number of fans
unsigned int numberOfFans = [smc numberOfFans];
NSLog(@"Fans: %d", numberOfFans);

// Get fan speed and min/max
for (int f = 0; f < numberOfFans; f++) {
    NSLog(@"Fan %d speed: %f", f, [smc speedOfFan:f]);
    NSLog(@"Fan %d min speed: %f", f, [smc minimumSpeedOfFan:f]);
    NSLog(@"Fan %d max speed: %f", f, [smc maximumSpeedOfFan:f]);
}

// Get approximate CPU temp (maximum value reported by any CPU sensor)
NSLog(@"CPU temp: %f", [smc cpuTemperatureInDegreesCelsius]);

// Get all temperature sensor values
for (NSString *key in smc.workingTempKeys) {
    NSLog(@"%@ %@: %f", key, [smc humanReadableNameForKey:key], [smc readNumberForKey:key]);
}

// Get all voltages
for (NSString *key in smc.workingVoltageKeys) {
    NSLog(@"%@ %@: %f", key, [smc humanReadableNameForKey:key], [smc readNumberForKey:key]);
}

// Get all current sensor values
for (NSString *key in smc.workingCurrentKeys) {
    NSLog(@"%@ %@: %f", key, [smc humanReadableNameForKey:key], [smc readNumberForKey:key]);
}

// Get all power usage values
for (NSString *key in smc.workingPowerKeys) {
    NSLog(@"%@ %@: %f", key, [smc humanReadableNameForKey:key], [smc readNumberForKey:key]);
}
```

## App Store warning
[Apple has previously blocked apps that access the SMC from the Mac App Store](https://www.tunabellysoftware.com/tgupdate/).
