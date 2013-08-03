##
# cdn-syncer
# na
#
# Copyright (c) 2013 yi
# Licensed under the na license.
##

p = require "commander"
walk = require "walk"
logger = require "dev-logger"
_ = require "underscore"
env = require './environment'

## 更新外部配置
p.version('0.1.0')
  .option('-c, --config-file [FILE]', 'Configuration json file')
  .parse(process.argv)

if p.configFile
  logger.info "[cdn-syncer::init] Load configuration from #{p.configFile}"
  env.load p.configFile
else
  logger.error "[cdn-syncer::init] missing configuration file, please use -c"
  process.exit(1)

assetsKV = {}

startAt = Date.now()

logger.log "[cdn-syncer::start] find all sgf files from #{env.LOCAL_DEPOT_ROOT}"

# listing assets files
walker = walk.walk(env.LOCAL_DEPOT_ROOT, env.WALK_OPTIONS)

walker.on "file", (root, fileStats, next) ->
  fileName = fileStats.name
  #logger.log "[cdn-syncer::on file] name:#{fileName}, root:#{root}"
  #console.dir fileStats

  unless env.REGEX_FILE_NAME
    assetsKV[fileName] = root
  else
    if env.REGEX_FILE_NAME.test(fileName)
      assetsKV[fileName] = root
    else
      logger.warn "[cdn-syncer::on file] ignore invalid asset:#{fileName}"

  next()
  return

walker.on "errors", (root, nodeStatsArray, next) ->
  logger.error "[cdn-syncer::on error] #{arguments}"
  process.exit(1)
  return

walker.on "end", ->
  logger.log "[cdn-syncer::list file] file #{_.keys(assetsKV).length} assets, time spent:#{Date.now() - startAt} ms"
  process.exit(0)
  return



