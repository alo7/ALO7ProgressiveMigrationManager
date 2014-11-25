//    ALO7ProgressiveMigrationManager.m
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

#import "ALO7ProgressiveMigrationManager.h"
#import "ALO7ProgressiveMigrationStepManager.h"


@interface ALO7ProgressiveMigrationManager() <ALO7ProgressiveMigrateDelegate>
@property (nonatomic, strong) NSArray *allDataModelPaths;
@property (nonatomic, strong, readwrite) NSManagedObjectModel *migrationSrcModel;
@end

@implementation ALO7ProgressiveMigrationManager
+ (instancetype)sharedManager
{
    static dispatch_once_t onceToken;
    static ALO7ProgressiveMigrationManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[ALO7ProgressiveMigrationManager alloc] init];
        manager.delegate = manager;
    });
    
    return manager;
}

- (BOOL)migrateStoreAtUrl:(NSURL *)srcStoreUrl storeType:(NSString *)storeType targetModel:(NSManagedObjectModel *)targetModel error:(NSError **)error
{
    if (!self.delegate) {
        NSLog(@"%@ need a delegate to perform progressive migration!", NSStringFromClass([self class]));
        return NO;
    }
    
    // 整理出migration所需的最少步骤：将连续的轻量级migration合并在一步内
    ALO7ProgressiveMigrationStepManager *stepManager = [[ALO7ProgressiveMigrationStepManager alloc] init];
    BOOL isMigrateStepsGenerated = [self generateMigrateStepsWithManager:stepManager forStoreAtUrl:srcStoreUrl storeType:storeType targetMode:targetModel error:error];
    if (!isMigrateStepsGenerated) {
        NSLog(@"%@ generate migrate steps failed!", NSStringFromClass([self class]));
        return NO;
    }
    
    // 打印steps信息
    NSLog(@"%@", stepManager);
    
    __block BOOL isMigrateOk = YES;
    // 根据整理出的migration步骤，逐步进行migration
    [stepManager enumerateStepsUsingBlock:^(ALO7ProgressiveMigrationStep *step, NSUInteger idx, BOOL *stop){
        if(![self migrateOneStep:step forStoreAtUrl:srcStoreUrl storeType:storeType error:error]) {
            isMigrateOk = NO;
            *stop = YES;
        }
    }];
    
    return isMigrateOk;
}

#pragma mark - Migrate details(private methods)

- (BOOL)generateMigrateStepsWithManager:(ALO7ProgressiveMigrationStepManager *)stepManager forStoreAtUrl:(NSURL *)srcStoreUrl storeType:(NSString *)storeType targetMode:(NSManagedObjectModel *)targetModel  error:(NSError **)error
{
    // 从src store中取出model的meta信息, 再根据meta从bundle中找出对应的data model
    NSDictionary *srcMetaData = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:storeType URL:srcStoreUrl error:error];
    if (!srcMetaData) {
        *error = [ALO7ProgressiveMigrationError errorWithCode:kALO7ProgressiveMigrateErrorSrcStoreMetaDataNotFound];
        return NO;
    }
    NSManagedObjectModel *srcModel = [NSManagedObjectModel mergedModelFromBundles:nil forStoreMetadata:srcMetaData];
    self.migrationSrcModel = srcModel;
    if (!srcModel) {
        *error = [ALO7ProgressiveMigrationError errorWithCode:kALO7ProgressiveMigrateErrorSrcStoreDataModelNotFound];
        return NO;
    }
    
    // 从src data model开始，循环寻找下一个data model，记录两个model之间的migration步骤；一直到target model为止。
    NSManagedObjectModel *nextModel;
    while (1) {
        // 通过delegate判断当前model是否和target model相同
        if ([self.delegate respondsToSelector:@selector(modelA:equalsToModelB:)]) {
            if ([self.delegate modelA:srcModel equalsToModelB:targetModel]) {
                break;
            }
        } else { // 如果delegate没有实现比较两个model的自定义规则，则采用默认方式，比较model的entityVersionHashesByName属性
            if ([self modelA:srcModel defaultEqualsToModelB:targetModel]) {
                break;
            }
        }
        
        // 通过delegate找出当前model的下一个data model,这个delegate方法是必须要实现的。
        nextModel = [self.delegate nextModelOfModel:srcModel amongModelPaths:self.allDataModelPaths];
        if (!nextModel) {
            *error = [ALO7ProgressiveMigrationError errorWithCode:kALO7ProgressiveMigrateErrorNextDataModelNotFound];
            return NO;
        }
        
        // 尝试寻找两个相邻的model之间的mapping model
        NSMappingModel *mappingModel = [NSMappingModel mappingModelFromBundles:nil forSourceModel:srcModel destinationModel:nextModel];
        if (mappingModel) {
            // mapping model存在, 创建一个heavy migration step
            [stepManager addOneStep:[ALO7ProgressiveMigrationStep stepOfHeavyWeightWithSrcModel:srcModel desModel:nextModel mappingModel:mappingModel]];
        } else {
            // mapping model不存在, 创建一个light migration step;
            // stepManager会自动将相邻的light weight migration合并在一起作为一步
            [stepManager addOneStep:[ALO7ProgressiveMigrationStep stepOfLightWeightWithSrcModel:srcModel desModel:nextModel]];
        }
        
        srcModel = nextModel;
    }
    
    return YES;
}

- (BOOL)migrateOneStep:(ALO7ProgressiveMigrationStep *)oneStep forStoreAtUrl:(NSURL *)srcStoreUrl storeType:(NSString *)storeType error:(NSError **)error
{
    if (oneStep.migrationType == kALO7ProgressiveMigrationStepLightWeight) {
        return [self lightweightMigrationURL:srcStoreUrl toModel:oneStep.desModel type:storeType error:error];
    } else if (oneStep.migrationType == kALO7ProgressiveMigrationStepHeavyWeight) {
        return [self heavyweightMigrationURL:srcStoreUrl srcModel:oneStep.srcModel desModel:oneStep.desModel mappingModel:oneStep.mappingModel storeType:storeType error:error];
    } else {
        NSLog(@"migrate one step, type error %@", oneStep);
        return NO;
    }
    
    return YES;
}

- (BOOL)lightweightMigrationURL:(NSURL *)sourceStoreURL toModel:(NSManagedObjectModel *)destinationModel type:(NSString *)type error:(NSError **)error {
    NSDictionary *storeOptions = @{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                   NSInferMappingModelAutomaticallyOption: @YES,
                                   NSSQLitePragmasOption: @{@"journal_mode" : @"WAL"}
                                   };
    
    NSPersistentStoreCoordinator *storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:destinationModel];
    
    [storeCoordinator lock];
    NSPersistentStore *persistentStore = [storeCoordinator addPersistentStoreWithType:type configuration:nil URL:sourceStoreURL options:storeOptions error:error];
    [storeCoordinator unlock];
    
    if (persistentStore == nil) {
        *error = [ALO7ProgressiveMigrationError errorWithCode:kALO7ProgressiveMigrateErrorLigthWeightMigrationFail];
    }
    
    return (persistentStore != nil);
}

- (BOOL)heavyweightMigrationURL:(NSURL *)sourceStoreURL srcModel:(NSManagedObjectModel *)srcModel desModel:(NSManagedObjectModel *)desModel mappingModel:(NSMappingModel *)mappingModel storeType:(NSString *)type error:(NSError **)error
{

    NSMigrationManager *migrateManager = [[NSMigrationManager alloc]
                                   initWithSourceModel:srcModel
                                   destinationModel:desModel];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *srcStoreExtension = [[sourceStoreURL path] pathExtension];
    NSString *srcStorePath = [[sourceStoreURL path] stringByDeletingPathExtension];
    
    // 创建两个文件path，用于存放新的db文件和备份老的db文件。创建完path后，检查一下path下是否已经存在文件，如果有，可能是以前不成功的migraion留下的，需要删除掉。
    NSString *newStorePath = [NSString stringWithFormat:@"%@.new.%@", srcStorePath, srcStoreExtension];
    NSURL *newStoreURL = [NSURL fileURLWithPath:newStorePath];
    if ([fileManager fileExistsAtPath:newStorePath]) {
        [fileManager removeItemAtPath:newStorePath error:nil];
    }
    NSString *backupStorePath = [NSString stringWithFormat:@"%@.backup.%@", srcStorePath, srcStoreExtension];
    if ([fileManager fileExistsAtPath:backupStorePath]) {
        [fileManager removeItemAtPath:backupStorePath error:nil];
    }
    
    // heavy migraion
    if (![migrateManager migrateStoreFromURL:sourceStoreURL type:type options:nil withMappingModel:mappingModel toDestinationURL:newStoreURL destinationType:type destinationOptions:nil error:error]) {
        return NO;
    }

    // 备份原始store文件
    if (![fileManager moveItemAtPath:[sourceStoreURL path] toPath:backupStorePath error:nil]) {
        *error = [ALO7ProgressiveMigrationError errorWithCode:kALO7ProgressiveMigrateErrorHeavyWeightMigrationBackupOriginStoreFail];
        return NO;
    }
    
    // 用新store替换原始store，如果替换失败，尝试将备份的store文件恢复
    if (![fileManager moveItemAtPath:newStorePath toPath:[sourceStoreURL path] error:nil]) {
        [fileManager moveItemAtPath:backupStorePath toPath:[sourceStoreURL path] error:nil];
        *error = [ALO7ProgressiveMigrationError errorWithCode:kALO7ProgressiveMigrateErrorHeavyWeightMigrationCopyNewStoreFail];
        return NO;
    }
    
    // 删除中间文件
    [fileManager removeItemAtPath:newStorePath error:nil];
    [fileManager removeItemAtPath:backupStorePath error:nil];
    
    return YES;
}

#pragma mark - The manager self is the default ALO7ProgressiveMigrateDelegate
- (NSManagedObjectModel *)nextModelOfModel:(NSManagedObjectModel *)model amongModelPaths:(NSArray *)allModelPaths;
{
    NSInteger sourceVersionNumber = [model ALO7_VersionNumber];
    if (sourceVersionNumber == kALO7InvalidModelVersionNumber) {
        return nil;
    }
    
    // 自定义的next model规则：version number递增
    NSSet *nextVersionIdentifiers = [NSSet setWithObject:[NSString stringWithFormat:@"%ld", (long)sourceVersionNumber + 1]];
    for (NSString * path in allModelPaths) {
        NSManagedObjectModel *oneModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
        if ([oneModel.versionIdentifiers isEqualToSet:nextVersionIdentifiers]) {
            return oneModel;
        }
    }
    
    return nil;
}

- (BOOL)modelA:(NSManagedObjectModel *)modelA equalsToModelB:(NSManagedObjectModel *)modelB
{
    NSInteger modelAVersionNumber = [modelA ALO7_VersionNumber];
    NSInteger modelBVersionNumber = [modelB ALO7_VersionNumber];
    
    if (modelAVersionNumber == kALO7InvalidModelVersionNumber || modelBVersionNumber == kALO7InvalidModelVersionNumber) {
        return NO;
    } else {
        return (modelAVersionNumber == modelBVersionNumber);
    }
}

#pragma mark - Helpers

- (NSArray *)allDataModelPaths
{
    if (!_allDataModelPaths) {
        NSMutableArray *modelPaths = [NSMutableArray array];
        
        // 从model bundles内收集data model
        NSArray *momdArray = [[NSBundle mainBundle] pathsForResourcesOfType:@"momd" inDirectory:nil];
        for (NSString *momdPath in momdArray) {
            NSString *resourceSubpath = [momdPath lastPathComponent];
            NSArray *array = [[NSBundle mainBundle] pathsForResourcesOfType:@"mom" inDirectory:resourceSubpath];
            [modelPaths addObjectsFromArray:array];
        }
        
        // 直接在main bundle下面收集data model
        NSArray* otherModels = [[NSBundle mainBundle] pathsForResourcesOfType:@"mom" inDirectory:nil];
        [modelPaths addObjectsFromArray:otherModels];
        
        _allDataModelPaths = [modelPaths copy];
    }
    
    return _allDataModelPaths;
}

- (BOOL)modelA:(NSManagedObjectModel *)modelA defaultEqualsToModelB:(NSManagedObjectModel *)modelB
{
    return [[modelA entityVersionHashesByName] isEqualToDictionary:[modelB entityVersionHashesByName]];
}
@end













