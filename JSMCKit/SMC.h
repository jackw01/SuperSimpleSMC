// SuperSimpleSMC
// Improved SMC library
// Copyright (C) 2018 jackw01. Released under the MIT license.

#import <stdio.h>
#import <string.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>

@interface SMC : NSObject

+ (instancetype)smc;

@property (strong) NSArray *allTempKeys;
@property (strong) NSArray *allVoltageKeys;
@property (strong) NSArray *allCurrentKeys;
@property (strong) NSArray *allPowerKeys;
@property (strong) NSArray *workingTempKeys;
@property (strong) NSArray *workingVoltageKeys;
@property (strong) NSArray *workingCurrentKeys;
@property (strong) NSArray *workingPowerKeys;

- (NSString *)humanReadableNameForKey:(NSString *)key;
- (float)readNumberForKey:(NSString *)key;

- (unsigned int)ambientLightInLux;

- (unsigned int)numberOfFans;
- (float)speedOfFan:(NSUInteger)fan;
- (float)minimumSpeedOfFan:(NSUInteger)fan;
- (float)maximumSpeedOfFan:(NSUInteger)fan;

- (float)cpuTemperatureInDegreesCelsius;

@end
