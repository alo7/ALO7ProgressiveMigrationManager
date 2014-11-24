//    AXTProgressiveMigrationStepManager.m
//
//    The MIT License (MIT)
//
//    Copyright (c) 2014 AXTProgressiveMigrationManager https://github.com/Alo7TechTeam
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE

#import "AXTProgressiveMigrationStepManager.h"
#import "NSManagedObjectModel+AXTUtil.h"

@interface AXTProgressiveMigrationStepManager()
@property (nonatomic, strong) NSMutableArray *allSteps;
@end

@implementation AXTProgressiveMigrationStepManager
- (void)addOneStep:(AXTProgressiveMigrationStep *)step
{
    if (step.migrationType == kAXTProgressiveMigrationStepHeavyWeight) {
        BOOL isNeedInsertOneLightStep = NO;
        
        /* Bug: 如果第一步就是 heavy migration 会失败，尚未查出原因，目前采用规避的方式来解决;
         * 当发现heavy migration前没有其它步骤，或者前一步不是light migration时，插入一步light migration;
         * 这一步light migration的src和des model均为heavy migration的src model.
         */
        if ([self.allSteps count] == 0) {
            isNeedInsertOneLightStep = YES;
        } else {
            AXTProgressiveMigrationStep *lastStep = [self.allSteps lastObject];
            if (lastStep.migrationType != kAXTProgressiveMigrationStepLightWeight) {
                isNeedInsertOneLightStep = YES;
            }
        }
        
        if (isNeedInsertOneLightStep) {
            [self.allSteps addObject:[AXTProgressiveMigrationStep stepOfLightWeightWithSrcModel:step.srcModel desModel:step.srcModel]];
        }
        /* End of Bug resolution*/
        
        [self.allSteps addObject:step];
    } else if (step.migrationType == kAXTProgressiveMigrationStepLightWeight) {
        // add lightWeigth step: 如果有前一步，并且前一步也是light migration, 则合并为一步；否则，添加为新的一步
        if ([self.allSteps count] > 0) {
            AXTProgressiveMigrationStep *lastStep = [self.allSteps lastObject];
            if (lastStep.migrationType == kAXTProgressiveMigrationStepLightWeight) {
                AXTProgressiveMigrationStep *mergedStep = [AXTProgressiveMigrationStep stepOfLightWeightWithSrcModel:lastStep.srcModel desModel:step.desModel];
                [self.allSteps replaceObjectAtIndex:[self.allSteps indexOfObject:lastStep] withObject:mergedStep];
            } else {
                [self.allSteps addObject:step];
            }
        } else {
            [self.allSteps addObject:step];
        }
    } else {
        NSLog(@"%@ %@ wrong type of migration step %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), step);
    }
}

- (void)enumerateStepsUsingBlock:(void (^)(AXTProgressiveMigrationStep *step, NSUInteger idx, BOOL *stop))block
{
    [self.allSteps enumerateObjectsUsingBlock:block];
}

- (NSMutableArray *)allSteps
{
    if (!_allSteps) {
        _allSteps = [NSMutableArray array];
    }
    
    return _allSteps;
}

- (NSString *)description
{
    NSString *log = [NSString stringWithFormat:@"progressive migration total steps count %lu\n", (unsigned long)[self.allSteps count]];
    
    for (int i = 0; i < [self.allSteps count]; i++) {
        log = [log stringByAppendingString:[NSString stringWithFormat:@"step%i: %@\n",i, self.allSteps[i]]];
    }
    
    return log;
}

@end

@implementation AXTProgressiveMigrationStep
+ (AXTProgressiveMigrationStep *)stepOfLightWeightWithSrcModel:(NSManagedObjectModel *)srcModel desModel:(NSManagedObjectModel *)desModel
{
    AXTProgressiveMigrationStep *step = [[AXTProgressiveMigrationStep alloc] init];
    step.migrationType = kAXTProgressiveMigrationStepLightWeight;
    step.srcModel = srcModel;
    step.desModel = desModel;
    step.mappingModel = nil;
    
    return step;
}

+ (AXTProgressiveMigrationStep *)stepOfHeavyWeightWithSrcModel:(NSManagedObjectModel *)srcModel desModel:(NSManagedObjectModel *)desModel mappingModel:(NSMappingModel *)mappingModel
{
    AXTProgressiveMigrationStep *step = [[AXTProgressiveMigrationStep alloc] init];
    step.migrationType = kAXTProgressiveMigrationStepHeavyWeight;
    step.srcModel = srcModel;
    step.desModel = desModel;
    step.mappingModel = mappingModel;
    
    return step;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"type:%@, src model version:%li, target model version:%li",
            [self migrationTypeDesc], (long)[self.srcModel AXT_VersionNumber], (long)[self.desModel AXT_VersionNumber]];
}

- (NSString *)migrationTypeDesc
{
    switch (self.migrationType) {
        case kAXTProgressiveMigrationStepLightWeight:
            return @"lightweight migraion";
            break;
            
        case kAXTProgressiveMigrationStepHeavyWeight:
            return @"heightweight migraion";
            break;
            
        default:
            return @"unknown type migration";
            break;
    }
}

@end
