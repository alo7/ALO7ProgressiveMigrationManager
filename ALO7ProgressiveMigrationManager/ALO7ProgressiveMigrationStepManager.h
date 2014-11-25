//    ALO7ProgressiveMigrationStepManager.h
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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

typedef NS_ENUM(NSUInteger, ALO7ProgressiveMigrationStepType_E) {
    kALO7ProgressiveMigrationStepLightWeight = 1,
    kALO7ProgressiveMigrationStepHeavyWeight
};
@class ALO7ProgressiveMigrationStep;

@interface ALO7ProgressiveMigrationStepManager : NSObject
- (void)addOneStep:(ALO7ProgressiveMigrationStep *)step;
- (void)enumerateStepsUsingBlock:(void (^)(ALO7ProgressiveMigrationStep *step, NSUInteger idx, BOOL *stop))block;
@end

@interface ALO7ProgressiveMigrationStep : NSObject
@property (nonatomic, assign) ALO7ProgressiveMigrationStepType_E migrationType;
@property (nonatomic, strong) NSManagedObjectModel *srcModel;
@property (nonatomic, strong) NSManagedObjectModel *desModel;
@property (nonatomic, strong) NSMappingModel *mappingModel;

+ (ALO7ProgressiveMigrationStep *)stepOfLightWeightWithSrcModel:(NSManagedObjectModel *)srcModel desModel:(NSManagedObjectModel *)desModel;
+ (ALO7ProgressiveMigrationStep *)stepOfHeavyWeightWithSrcModel:(NSManagedObjectModel *)srcModel desModel:(NSManagedObjectModel *)desModel mappingModel:(NSMappingModel *)mappingModel;
@end