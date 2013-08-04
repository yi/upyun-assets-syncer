Upyun Assets Syncer
===================

一个可配置的又拍云CDN(upyun.com)素材同步程序，基于 NodeJS 和 CoffeeScritpt


## 为什么需要这个工具

* 当CDN上的素材超过10000时，UPYUN的LISTING API无法将超过10000的文件信息返回，FTP亦然
* 当本地素材发生频繁修改时，需要增量同步工具以减少同步所花费的时间
* 当本地素材的同步时，需要配合特定的文件过滤逻辑时

这个工具是对 find + rsync 的扩展性补充。

## 安装

    # 安装 coffee-script
    sudo npm install -g coffee-script

## 运行

    upsyncer -c config.json      # 根据config.json 中的设定执行同步操作

    upsyncer -c config.json -t   #  根据config.json 中的设定模拟同步操作,在结果中列出所有要被上传的文件

### 命令行参数

    -c, --config-file [FILE]  # 传入要执行的同步任务的配置JSON文件

    -t, --test-drive          # 模拟执行同步任务，列出所有要被同步的文件，但不实际执行上传操作

### 配置文件

```json
{

  "LOCAL_DEPOT_ROOT" : "/path/to/assets",

  "REGEX_FILE_NAME" : /[a-z0-9]{11}\.sgf/,

  "BUCKETNAME" : "__________",

  "USERNAME" : "________",

  "PASSWORD" : "________",

  "REVISION_SENSITIVE" : false,

  "PARALLELY" : true,

  "VERBOSE" : false,

  "WALK_OPTIONS" : {
    "followLinks" : false
  }

}

```

其中：


**LOCAL_DEPOT_ROOT:String**

同步素材所在的根目录，其下的子目录将被遍历

**REGEX_FILE_NAME:RegExp**

一个过滤文件名的正则表达式，只有满足表达式条件的文件才会被添加到同步的检查列表中。如果不提供这个设置，那么根目录下遍历到的所有文件将被进行同步

**BUCKETNAME:String**

UPYUN API 的 bucket name

**USERNAME:String**

UPYUN API 的 user name

**PASSWORD:String**

UPYUN API 的 password

**REVISION_SENSITIVE:Boolean**

当True时，将对本地文件和服务器文件做 md5 比对，md5 不同的话，将会把本地文件重新上传 upyun

**PARALLELY:Boolean**

当 True 时，将会采用并发操作，对于大文件量时，可以有效提高速度，但是在老版本的 NodeJS 上会遇到 http parse error

**VERBOSE:Boolean**

当 True 时，将输出操作中的具体调试信息





