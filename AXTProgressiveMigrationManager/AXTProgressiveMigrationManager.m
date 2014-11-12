//    AXTProgressiveMigrationManager.m
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
//    SOFTWARE.

#import "AXTProgressiveMigrationManager.h"
#import "AXTProgressiveMigrationStepManager.h"


@interface AXTProgressiveMigrationManager() <AXTProgressiveMigrateDelegate>
@property (nonatomic, strong) NSArray *allDataModelPaths;
@property (nonatomic, strong, readwrite) NSManagedObjectModel *migrationSrcModel;
@end

@implementation AXTProgressiveMigrationManager
+ (instancetype)sharedManager
{
    static dispatch_once_t onceToken;
    static AXTProgressiveMigrationManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[AXTProgressiveMigrationManager alloc] init];
        manager.delegate = manager;
    });
    
    return manager;
}

- (BOOL)migrateStoreAtUrl:(NSURL *)srcStoreUrl storeType:(NSString *)storeType targetModel:(NSManagedObjectModel *)targetModel error:(NSError **)error
{
    if (!self.delegate) {
        DDLogError(@"%@ need a delegate to perform progressive migration!", NSStringFromClass([self class]));
        return NO;
    }
    
    // 整理出migration所需的最少步骤：将连续的轻量级migration合并在一步内
    AXTProgressiveMigrationStepManager *stepManager = [[AXTProgressiveMigrationStepManager alloc] init];
    BOOL isMigrateStepsGenerated = [self generateMigrateStepsWithManager:stepManager forStoreAtUrl:srcStoreUrl storeType:storeType targetMode:targetModel error:error];
    if (!isMigrateStepsGenerated) {
        DDLogError(@"%@ generate migrate steps failed!", NSStringFromClass([self class]));
        return NO;
    }
    
    // 打印steps信息
    DDLogInfo(@"%@", stepManager);
    
    __block BOOL isMigrateOk = YES;
    // 根据整理出的migration步骤，逐步进行migration
    [stepManager enumerateStepsUsingBlock:^(AXTProgressiveMigrationStep *step, NSUInteger idx, BOOL *stop){
        if(![self migrateOneStep:step forStoreAtUrl:srcStoreUrl storeType:storeType error:error]) {
            isMigrateOk = NO;
            *stop = YES;
        }
    }];
    
    return isMigrateOk;
}

#pragma mark - Migrate details(private methods)

- (BOOL)generateMigrateStepsWithManager:(AXTProgressiveMigrationStepManager *)stepManager forStoreAtUrl:(NSURL *)srcStoreUrl storeType:(NSString *)storeType targetMode:(NSManagedObjectModel *)targetModel  error:(NSError **)error
{
    // 从src store中取出model的meta信息, 再根据meta从bundle中找出对应的data model
    NSDictionary *srcMetaData = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:storeType URL:srcStoreUrl error:error];
    if (!srcMetaData) {
        *error = [AXTProgressiveMigrationError errorWithCode:kAXTProgressiveMigrateErrorSrcStoreMetaDataNotFound];
        return NO;
    }
    NSManagedObjectModel *srcModel = [NSManagedObjectModel mergedModelFromBundles:nil forStoreMetadata:srcMetaData];
    self.migrationSrcModel = srcModel;
    if (!srcModel) {
        *error = [AXTProgressiveMigrationError errorWithCode:kAXTProgressiveMigrateErrorSrcStoreDataModelNotFound];
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
            *error = [AXTProgressiveMigrationError errorWithCode:kAXTProgressiveMigrateErrorNextDataModelNotFound];
            return NO;
        }
        
        // 尝试寻找两个相邻的model之间的mapping model
        NSMappingModel *mappingModel = [NSMappingModel mappingModelFromBundles:nil forSourceModel:srcModel destinationModel:nextModel];
        if (mappingModel) {
            // mapping model存在, 创建一个heavy migration step
            [stepManager addOneStep:[AXTProgressiveMigrationStep stepOfHeavyWeightWithSrcModel:srcModel desModel:nextModel mappingModel:mappingModel]];
        } else {
            // mapping model不存在, 创建一个light migration step;
            // stepManager会自动将相邻的light weight migration合并在一起作为一步
            [stepManager addOneStep:[AXTProgressiveMigrationStep stepOfLightWeightWithSrcModel:srcModel desModel:nextModel]];
        }
        
        srcModel = nextModel;
    }
    
    return YES;
}

- (BOOL)migrateOneStep:(AXTProgressiveMigrationStep *)oneStep forStoreAtUrl:(NSURL *)srcStoreUrl storeType:(NSString *)storeType error:(NSError **)error
{
    if (oneStep.migrationType == kAXTProgressiveMigrationStepLightWeight) {
        return [self lightweightMigrationURL:srcStoreUrl toModel:oneStep.desModel type:storeType error:error];
    } else if (oneStep.migrationType == kAXTProgressiveMigrationStepHeavyWeight) {
        return [self heavyweightMigrationURL:srcStoreUrl srcModel:oneStep.srcModel desModel:oneStep.desModel mappingModel:oneStep.mappingModel storeType:storeType error:error];
    } else {
        DDLogError(@"migrate one step, type error %@", oneStep);
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
        *error = [AXTProgressiveMigrationError errorWithCode:kAXTProgressiveMigrateErrorLigthWeightMigrationFail];
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
        *error = [AXTProgressiveMigrationError errorWithCode:kAXTProgressiveMigrateErrorHeavyWeightMigrationBackupOriginStoreFail];
        return NO;
    }
    
    // 用新store替换原始store，如果替换失败，尝试将备份的store文件恢复
    if (![fileManager moveItemAtPath:newStorePath toPath:[sourceStoreURL path] error:nil]) {
        [fileManager moveItemAtPath:backupStorePath toPath:[sourceStoreURL path] error:nil];
        *error = [AXTProgressiveMigrationError errorWithCode:kAXTProgressiveMigrateErrorHeavyWeightMigrationCopyNewStoreFail];
        return NO;
    }
    
    // 删除中间文件
    [fileManager removeItemAtPath:newStorePath error:nil];
    [fileManager removeItemAtPath:backupStorePath error:nil];
    
    return YES;
}

#pragma mark - The manager self is the default AXTProgressiveMigrateDelegate
- (NSManagedObjectModel *)nextModelOfModel:(NSManagedObjectModel *)model amongModelPaths:(NSArray *)allModelPaths;
{
    NSInteger sourceVersionNumber = [model AXT_VersionNumber];
    if (sourceVersionNumber == kAXTInvalidModelVersionNumber) {
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
    NSInteger modelAVersionNumber = [modelA AXT_VersionNumber];
    NSInteger modelBVersionNumber = [modelB AXT_VersionNumber];
    
    if (modelAVersionNumber == kAXTInvalidModelVersionNumber || modelBVersionNumber == kAXTInvalidModelVersionNumber) {
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













