//    NSManagedObjectModel+ALO7Util.m
//
//    The MIT License (MIT)
//
//    Copyright (c) 2014 ALO7ProgressiveMigrationManager https://github.com/Alo7TechTeam
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


#import "NSManagedObjectModel+ALO7Util.h"

const NSInteger kALO7InvalidModelVersionNumber = -1;

@implementation NSManagedObjectModel (ALO7Util)
- (NSInteger)ALO7_VersionNumber
{
    NSString *modelVersionIdentifier = [self.versionIdentifiers anyObject];
    
    return modelVersionIdentifier?[modelVersionIdentifier integerValue]:kALO7InvalidModelVersionNumber;
}

- (BOOL)ALO7_isMigrationNeededWithStoreType:(NSString *)storeType atPath:(NSString *)storePath
{
    NSError *error = nil;
    BOOL pscCompatibile = NO;
    NSDictionary *sourceMetadata;
    NSURL *storeUrl;
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:storePath]){
        pscCompatibile = YES;
    } else {
        storeUrl = [NSURL fileURLWithPath:storePath];

        sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:storeUrl error:&error];
        pscCompatibile = [self isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata];
    }

    return !pscCompatibile;
}
@end
