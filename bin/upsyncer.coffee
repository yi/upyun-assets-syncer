#!/usr/bin/env coffee

##
# cdn-syncer
# na
#
# Copyright (c) 2013 yi
# Licensed under the na license.
##

fs = require "fs"
p = require "commander"
walk = require "walk"
logger = require "dev-logger"
_ = require "underscore"
async = require "async"
checksum = require "checksum"
upyun = require "upyun"

## settings scarfollding

settings =

  # 本地文件仓库目录
  LOCAL_DEPOT_ROOT : "/path/to/assets"

  # option for node-walk
  WALK_OPTIONS :
    'followLinks' : false

  # reg exp pattern for valid asset file name
  #REGEX_FILE_NAME : /[a-z0-9]{11}\.sgf/
  REGEX_FILE_NAME : null

  # 加载外部配置的帮助方法
  load: (filePath) ->
    logger.log "[environment::load] filePath:#{filePath}"

    #data = JSON.parse(fs.readFileSync(filePath))
    data = fs.readFileSync(filePath).toString()
    #logger.log "[environment::method] data:#{data}"
    data = eval("function x(){ return " + data + "; }")
    data = x()

    # NOTE:
    #   why use eval, rather then JSON.parse()
    #   refer to: http://stackoverflow.com/questions/8328119/can-i-store-regexp-and-function-in-json
    #   and http://stackoverflow.com/a/14063796
    # ty 2013-08-04

    #console.dir data

    for own key, value of data
      settings[key] = value

    return

## updating args
p.version('0.1.0')
  .option('-c, --config-file [FILE]', 'Configuration json file')
  .parse(process.argv)

if p.configFile
  logger.info "[cdn-syncer::init] Load configuration from #{p.configFile}"
  settings.load p.configFile
else
  logger.error "[cdn-syncer::init] missing configuration file, please use -c"
  process.exit(1)


## runtime vars
assetsKV = {}

startAt = Date.now()

# create upyun client
client = upyun settings.BUCKETNAME, settings.USERNAME, settings.PASSWORD

# make sure the given upyun account is authorized
client.getUsage (err, status, data)->
  unless status is 200
    throw(new Error("Upyun account (#{settings.USERNAME}:#{settings.PASSWORD}@#{settings.BUCKETNAME}) failed authorization"))
    process.exit(1)
  return

# process an individual asset
processAsset = (fileName, next)->
  fullPath = "#{assetsKV[fileName]}/#{fileName}"

  content = fs.readFileSync fullPath

  sumLocal = checksum content.toString('hex')

  client.downloadFile fileName, (err, status, data) ->

    logger.log "[upsyncer::processAsset::downloadFile] err:#{err}, status:#{status}"

    switch status
      when 404
        # file not on cdn, so upload it
        client.uploadFile fileName, content, (err, status, data)->
          if err? or status isnt 200
            logger.error "[upsyncer::processAsset::upload] failed. err:#{err}, status:#{status}"
            next null,
              'status' : status
              'fileName' : fileName
              'action' : 'upload'
              'err' : err
          else
            logger.info "[upsyncer::processAsset::upload] put asset:#{fileName}"
            next null
          return

      when 200
        # file exist on cdn, skip
        logger.log "[upsyncer::processAsset::upload] skip asset:#{fileName}"
        next null
      else
        # unrecoginsed status code
        next("unrecoginsed status code:#{status}")

    return


  # check local sum
  #checksum.file fullPath, (err, sumLocal)->
    #if err?
      #next("[upsyncer::processAsset] fail to check local sum. fullPath:#{fullPath}, err:#{err}")
      #return

    #logger.log "[upsyncer::processAsset] fileName:#{fileName}, fullPath:#{fullPath}, local sum:#{sumLocal}"

    #client.downloadFile fileName, (err, status, data) ->

      #switch status
        #when 404
          ## file not on cdn, so upload it
          #client.


      #logger.log "[upsyncer::processAsset::downloadFile] err:#{err}, status:#{status}, data:#{data}"
      #next(null, sumLocal)
      #return

  return

generateResult = (err, results)->
  logger.log "[upsyncer::generateResult] results:#{results}, err:#{err}"
  process.exit(0)
  return

## starting job
logger.log "[cdn-syncer::start] find all sgf files from #{settings.LOCAL_DEPOT_ROOT}"

# listing assets files
walker = walk.walk(settings.LOCAL_DEPOT_ROOT, settings.WALK_OPTIONS)

walker.on "file", (root, fileStats, next) ->
  fileName = fileStats.name
  #logger.log "[cdn-syncer::on file] name:#{fileName}, root:#{root}"
  #console.dir fileStats

  unless settings.REGEX_FILE_NAME
    assetsKV[fileName] = root
  else
    if settings.REGEX_FILE_NAME.test(fileName)
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
  assetsList = _.keys assetsKV
  logger.log "[cdn-syncer::list file] file #{assetsList.length} assets, time spent:#{Date.now() - startAt} ms"
  #process.exit(0)

  async.map(assetsList, processAsset, generateResult)

  return



