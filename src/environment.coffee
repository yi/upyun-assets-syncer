logger = require "dev-logger"
fs = require "fs"

# 设置表
settings =

  DEBUG: true

  # 本地文件仓库目录
  LOCAL_DEPOT_ROOT : "/path/to/assets"

  WALK_OPTIONS :
    'followLinks' : false

  # 加载外部配置的帮助方法
  load: (filePath) ->
    logger.log "[environment::load] filePath:#{filePath}"

    data = JSON.parse(fs.readFileSync(filePath))

    for own key, value of data
      settings[key] = value

    return

module.exports = settings
