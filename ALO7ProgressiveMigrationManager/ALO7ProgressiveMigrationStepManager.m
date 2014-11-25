//    ALO7ProgressiveMigrationStepManager.m
//
//    Copyright (c) 2014-present, ALO7, Inc. https://github.com/alo7
//    All rights reserved.
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions are met:
//
//    * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//    * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//    * Neither the name of test nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//             SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "ALO7ProgressiveMigrationStepManager.h"
#import "NSManagedObjectModel+ALO7Util.h"

@interface ALO7ProgressiveMigrationStepManager()
@property (nonatomic, strong) NSMutableArray *allSteps;
@end

@implementation ALO7ProgressiveMigrationStepManager
- (void)addOneStep:(ALO7ProgressiveMigrationStep *)step
{
    if (step.migrationType == kALO7ProgressiveMigrationStepHeavyWeight) {
        BOOL isNeedInsertOneLightStep = NO;
        
        /* Bug: 如果第一步就是 heavy migration 会失败，尚未查出原因，目前采用规避的方式来解决;
         * 当发现heavy migration前没有其它步骤，或者前一步不是light migration时，插入一步light migration;
         * 这一步light migration的src和des model均为heavy migration的src model.
         */
        if ([self.allSteps count] == 0) {
            isNeedInsertOneLightStep = YES;
        } else {
            ALO7ProgressiveMigrationStep *lastStep = [self.allSteps lastObject];
            if (lastStep.migrationType != kALO7ProgressiveMigrationStepLightWeight) {
                isNeedInsertOneLightStep = YES;
            }
        }
        
        if (isNeedInsertOneLightStep) {
            [self.allSteps addObject:[ALO7ProgressiveMigrationStep stepOfLightWeightWithSrcModel:step.srcModel desModel:step.srcModel]];
        }
        /* End of Bug resolution*/
        
        [self.allSteps addObject:step];
    } else if (step.migrationType == kALO7ProgressiveMigrationStepLightWeight) {
        // add lightWeigth step: 如果有前一步，并且前一步也是light migration, 则合并为一步；否则，添加为新的一步
        if ([self.allSteps count] > 0) {
            ALO7ProgressiveMigrationStep *lastStep = [self.allSteps lastObject];
            if (lastStep.migrationType == kALO7ProgressiveMigrationStepLightWeight) {
                ALO7ProgressiveMigrationStep *mergedStep = [ALO7ProgressiveMigrationStep stepOfLightWeightWithSrcModel:lastStep.srcModel desModel:step.desModel];
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

- (void)enumerateStepsUsingBlock:(void (^)(ALO7ProgressiveMigrationStep *step, NSUInteger idx, BOOL *stop))block
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

@implementation ALO7ProgressiveMigrationStep
+ (ALO7ProgressiveMigrationStep *)stepOfLightWeightWithSrcModel:(NSManagedObjectModel *)srcModel desModel:(NSManagedObjectModel *)desModel
{
    ALO7ProgressiveMigrationStep *step = [[ALO7ProgressiveMigrationStep alloc] init];
    step.migrationType = kALO7ProgressiveMigrationStepLightWeight;
    step.srcModel = srcModel;
    step.desModel = desModel;
    step.mappingModel = nil;
    
    return step;
}

+ (ALO7ProgressiveMigrationStep *)stepOfHeavyWeightWithSrcModel:(NSManagedObjectModel *)srcModel desModel:(NSManagedObjectModel *)desModel mappingModel:(NSMappingModel *)mappingModel
{
    ALO7ProgressiveMigrationStep *step = [[ALO7ProgressiveMigrationStep alloc] init];
    step.migrationType = kALO7ProgressiveMigrationStepHeavyWeight;
    step.srcModel = srcModel;
    step.desModel = desModel;
    step.mappingModel = mappingModel;
    
    return step;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"type:%@, src model version:%li, target model version:%li",
            [self migrationTypeDesc], (long)[self.srcModel ALO7_VersionNumber], (long)[self.desModel ALO7_VersionNumber]];
}

- (NSString *)migrationTypeDesc
{
    switch (self.migrationType) {
        case kALO7ProgressiveMigrationStepLightWeight:
            return @"lightweight migraion";
            break;
            
        case kALO7ProgressiveMigrationStepHeavyWeight:
            return @"heightweight migraion";
            break;
            
        default:
            return @"unknown type migration";
            break;
    }
}

@end
