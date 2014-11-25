//    ALO7ProgressiveMigrationError.m
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

#import "ALO7ProgressiveMigrationError.h"

NSString *const kALO7ProgressiveMigrateErrorDomain = @"ALO7 Progressive Migrate Error";

@implementation ALO7ProgressiveMigrationError
+ (ALO7ProgressiveMigrationError *)errorWithCode:(ALO7ProgressiveMigrationError_e)code
{
    if (code >= kALO7ProgressiveMigrateErrorMax) {
        return nil;
    }
    
    NSString *desc;
    switch (code) {
        case kALO7ProgressiveMigrateErrorUnknown:
            desc = @"PROGRESSIVE_MIGRATE_ERROR_UNKNOWN";
            break;
            
        case kALO7ProgressiveMigrateErrorSrcStoreMetaDataNotFound:
            desc = @"PROGRESSIVE_MIGRATE_ERROR_SrcStoreMetaDataNotFound";
            break;
            
        case kALO7ProgressiveMigrateErrorSrcStoreDataModelNotFound:
            desc = @"PROGRESSIVE_MIGRATE_ERROR_SrcStoreDataModelNotFound";
            break;
            
        case kALO7ProgressiveMigrateErrorNextDataModelNotFound:
            desc = @"PROGRESSIVE_MIGRATE_ERROR_NextDataModelNotFound";
            break;
            
        case kALO7ProgressiveMigrateErrorLigthWeightMigrationFail:
            desc = @"PROGRESSIVE_MIGRATE_ERROR_LigthWeightMigrationFail";
            break;
            
        case kALO7ProgressiveMigrateErrorHeavyWeightMigrationBackupOriginStoreFail:
            desc = @"PROGRESSIVE_MIGRATE_ERROR_HeavyWeightMigrationBackupOriginStoreFail";
            break;
            
        case kALO7ProgressiveMigrateErrorHeavyWeightMigrationCopyNewStoreFail:
            desc = @"PROGRESSIVE_MIGRATE_ERROR_HeavyWeightMigrationCopyNewStoreFail";
            break;
            
        default:
            break;
    }
    
    NSDictionary *userInfo;
    if (desc) {
        userInfo = @{NSLocalizedDescriptionKey : desc};
    }

    ALO7ProgressiveMigrationError *error = [ALO7ProgressiveMigrationError errorWithDomain:kALO7ProgressiveMigrateErrorDomain code:code userInfo:userInfo];
    return error;
}
@end
