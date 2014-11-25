ALO7ProgressiveMigrationManager
==============================
![License BSD](https://go-shields.herokuapp.com/license-BSD-blue.png)
![Pod version](http://img.shields.io/cocoapods/v/ALO7ProgressiveMigrationManager.svg?style=flat)
#README
##ALO7ProgressiveMigrationManager
ALO7ProgressiveMigrationManager optimises the procedure of migrating the Core Data store on iOS platform.

In the situation of [lightweight][apple document lightweight] migration, Core Data framework could do the work automatically. But when the heavyweight migration is involved, the case becomes complicated. The developer needs to create a Mapping Model and a Mapping Policy to finish the migration work (see [official documentation][apple document migration]).

However, after the heavy migration is achieved, there comes a new problem with more trouble: Core Data framework does not support the progressive migration procedure. That is to say, for example, though a database can be migrated from Version2 to Version3 using heavyweight migration and from Version3 to Version4 using lightweight migration, it still needs a new mapping model defined by the developer to be migrated from Version2 to Version4. With the evolution of database version, the maintance will become incredibly difficult. 

ALO7ProgressiveMigrationManager offers support for migrating the Core Data database progressively. In the example above, the new mapping model for migrating from Version2 to Version4 is not needed any more. The basic idea comes from this great [Core Data Book][core data book] and some enhanced features are added to support a progressive migration with lightweight and heavyweight migration mixed. 

ALO7ProgressiveMigrationManager starts with finding the corresponding ManagedObjdectModel of the source database file, and searches for consecutive ManagedObjdectModels until the target ManagedObjdectModel is reached. For every two consecutive ManagedObjdectModel, ALO7ProgressiveMigrationManager checks if a corresponding Mapping Model exists. If exists, a step of heavyweight migration is performed; otherwise a step of lightweight migration is performed. The procedure reaches to an end when the database file is compatible with the target ManagedObjdectModel.
##How To Use
###Installation
Just drag-and-drop into your project. Or if you prefer to using Cocopods:

    pod 'ALO7ProgressiveMigrationManager', '~> 1.0.0'
###API
```
NSError *error;
/* Migrate the SQLite database file located at storePath to a new version 
 * which is compatible with the targetManagedObjectModel.
 */
Bool isSuccess = [[ALO7ProgressiveMigrationManager sharedManager] 
    					migrateStoreAtUrl:[NSURL fileURLWithPath:storePath] 
    					storeType:NSSQLiteStoreType 
    					targetModel:targetManagedObjectModel 
    					error:&error];
```
###Delegate(Optional)
ALO7ProgressiveMigrationManager needs a searching rule for ManagedObjectModel, thus it is able to find all consecutive ManagedObjectModels from the source to the target. This rule is implemented by the Protocol defined below:

```
@protocol ALO7ProgressiveMigrateDelegate <NSObject>
@required
- (NSManagedObjectModel *)nextModelOfModel:(NSManagedObjectModel *)model amongModelPaths:(NSArray *)allModelPaths;
@end
```

Assigning an instance which conforms to ```ALO7ProgressiveMigrateDelegate``` to the ```delegate``` property of ALO7ProgressiveMigrationManager to implement the searching rule. 

Notice that this configuration is optional, ALO7ProgressiveMigrationManager has a default internal searching rule which searches for the next consecutive ManagedObjectModel with the ```Identifier``` attribute increased by 1 (which is  set in the ManagedObjectModel`s file inspector panel in XCode). If you use the default searching rule, you need to ensure that the Identifier value of all ManagedObjectModels have been set correctly (e.g. 1, 2, 3, ...). And every new ManagedObjectModel added in the future also needs to be set with a correct Identifier value.
##Acknowledgements
ALO7ProgressiveMigrationManager learned a lot from [Marcus S. Zarra][core data book author twitter] - [Core Data Book][core data book]. Thanks for his great work.
##License
ALO7ProgressiveMigrationManager is available under the BSD license. See the LICENSE file for more info.

#帮助
##ALO7ProgressiveMigrationManager
ALO7ProgressiveMigrationManager 用来优化 iOS 上 Core Data 数据库的 Migration 工作。

在 Core Data 数据库升级只涉及[轻量级变更][apple document lightweight]的情况下，Core Data 框架可以自动完成升级工作；但如果涉及到重量级变更，情况就变得复杂了，开发者需要自定义Mapping Model 和 Mapping Policy来完成升级工作（参见[官方文档][apple document migration]）。

但实现自定义的重量级升级后，还有一个更麻烦的问题：Core Data 框架并不支持渐进式的数据库升级。假设数据库版本 Version2 到 Version3使用了重量级升级，之后 Version3 到 Version4 使用轻量级升级，那么从 Version2 到 Version4 的升级工作并不能基于已有的 Mapping Model 自动完成，而是需要开发者定义一个新的 Mapping Model 来对应 Version2 到 Version4 的升级工作。随着版本的增加，对于 Mapping Model 的维护工作将会变得非常麻烦和困难。

ALO7ProgressiveMigrationManager 提供了对于渐进式数据库升级的支持，对于上面的例子，Version2 到 Version4 的升级工作不再需要一个新的 mapping model. 基本思路来自于这本很不错的 [Core Data 教程][core data book]，在其基础上做了优化，支持轻量级升级和重量级升级混合在一起的渐进式升级。

ALO7ProgressiveMigrationManager 从源数据库文件对应的 managedObjectModel 开始，在 bundle 内一路搜索到升级的目标 managedObjectModel；并对每两个连续的 managedObjectModel，在 bundle 内搜索对应的 mapping model 是否存在，如果存在则进行一次重量级升级，否则进行一次轻量级升级；直到最后数据库文件和目标 managedObjectModel 相兼容。

##如何使用
###安装
把源文件拖入工程即可. 如果你喜欢用 CocoaPods 也可以:

    pod 'ALO7ProgressiveMigrationManager', '~> 1.0.0'
###API 调用
```
NSError *error;
/* 将位于 storePath 的 SQLite 数据库文件
 * 升级到和 Core Data 数据库模型targetManagedObjectModel 匹配的版本
 */
Bool isSuccess = [[ALO7ProgressiveMigrationManager sharedManager] 
    					migrateStoreAtUrl:[NSURL fileURLWithPath:storePath] 
    					storeType:NSSQLiteStoreType 
    					targetModel:targetManagedObjectModel 
    					error:&error];
```
###Delegate 配置(可选)
ALO7ProgressiveMigrationManager 需要一个 managedObjectModel 的搜索规则，来搜索出从源 managedObjectModel 到目标 managedObjectModel 的所有连续 managedObjectModel。这个规则通过下面的 Protocol 实现：

```
@protocol ALO7ProgressiveMigrateDelegate <NSObject>
@required
- (NSManagedObjectModel *)nextModelOfModel:(NSManagedObjectModel *)model amongModelPaths:(NSArray *)allModelPaths;
@end
```
将实现了 ```ALO7ProgressiveMigrateDelegate``` 的实体作为 ALO7ProgressiveMigrationManager 的 ```delegate``` 即可。这一步是可选的, 如果你不实现这一步，ALO7ProgressiveMigrationManager 默认的 managedObjectModel 搜索规则是：```Identifier```(在 dataModel 文件的 File Inspector 中设置) 递增 1。

因此，如果你采用默认的排序规则，需要手动将现有的所有 dataModel 文件的 Identifier 按版本顺序设置为递增的值：1、2、3、4......并且以后增加的新版本 dataModel 也要记得设置好 Identifier 值。
##感谢
ALO7ProgressiveMigrationManager基于 [Marcus S. Zarra][core data book author twitter]的 [Core Data 教程][core data book]内的思路进行开发，感谢他所撰写的这本教程。 
##协议
ALO7ProgressiveMigrationManager 被许可在 BSD 协议下使用, 查阅 LICENSE 文件来获得更多信息。

<!-- external links -->
[apple document lightweight]:https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/vmLightweightMigration.html
[apple document migration]:https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/Introduction.html#//apple_ref/doc/uid/TP40004399-CH1-SW1
[core data book]:https://pragprog.com/book/mzcd2/core-data
[core data book author twitter]:https://twitter.com/mzarra