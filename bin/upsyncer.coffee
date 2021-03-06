#!/usr/bin/env coffee

##
# upyun-assets-syncer
# a configurable node script to synce local assets to upyun cdn, compared by md5
#
# Copyright (c) 2013 yi
# Licensed under the MIT license.
##

fs = require "fs"
p = require "commander"
walk = require "walk"
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

  # True: will re-upload local asset if md5 not match
  UPLOAD_NEWLY_ASSET : true

  # reg exp pattern for valid asset file name
  #REGEX_FILE_NAME : /[a-z0-9]{11}\.sgf/
  REGEX_FILE_NAME : null

  IGNORE_ASSET_MODIFIED_BEFORE: 0

  # 加载外部配置的帮助方法
  load: (filePath) ->
    #console.log "[environment::load] filePath:#{filePath}"

    #data = JSON.parse(fs.readFileSync(filePath))
    data = fs.readFileSync(filePath).toString()
    #console.log "[environment::method] data:#{data}"
    try
      data = eval("function x(){ return " + data + "; }")
      data = x()
    catch err
      console.error "[upsyncer::settings::load] bad configuration json file, err:#{err}, input json:#{data}"
      process.exit(1)
      return

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
  .option('-c, --config-file <FILE>', 'Configuration json file')
  .option('-t, --test-drive', 'list all local assets which should be synced withouth uploading them to CDN')
  #.option('-s, --after-timestamp <date>', 'only sync assets last modified after the given time stamp')
  .parse(process.argv)

if p.configFile
  console.log "[cdn-syncer::init] Load configuration from #{p.configFile}"
  settings.load p.configFile
else
  console.error "[cdn-syncer::init] missing configuration file, please use -c"
  process.exit(1)

console.log "[upsyncer] start synce with following settings, at #{new Date}"
#console.log settings


## runtime vars
assetsKV = {}

countAssets = 0

countProgress = 0

startAt = Date.now()

# create upyun client
client = upyun settings.BUCKETNAME, settings.USERNAME, settings.PASSWORD

# make sure the given upyun account is authorized
client.getUsage (err, status, data)->
  unless status is 200
    throw(new Error("Upyun account (#{settings.USERNAME}:#{settings.PASSWORD}@#{settings.BUCKETNAME}) failed authorization"))
    process.exit(1)
  return

# upload an individual asset to upyun
uploadAsset = (fileName, contentLocal, next)->
  console.log "[upsyncer::uploadAsset] fileName:#{fileName}"

  if p.testDrive
    next null,
      'fileName' : fileName
      'action' : 'testdrive'
    return

  client.uploadFile fileName, contentLocal, (err, status, data)->
    if err? or status isnt 200
      #console.error "[upsyncer::uploadAsset] failed. err:#{err}, status:#{status}"
      next "[upsyncer::uploadAsset] failed. err:#{err}, status:#{status}"
    else
      console.info "[upsyncer::processAsset::upload] put asset:#{fileName}"
      next null,
        'status' : status
        'fileName' : fileName
        'action' : 'upload'
        'err' : err
    return
  return

# process an individual asset
processAsset = (fileName, next)->
  console.info "[upsyncer::processAsset] progress:#{++countProgress}/#{countAssets} - fileName:#{fileName}"

  fullPath = "#{assetsKV[fileName]}/#{fileName}"

  contentLocal = fs.readFileSync fullPath

  sumLocal = checksum(contentLocal.toString('binary'))

  client.downloadFile fileName, (err, status, contentRemote) ->

    console.log "[upsyncer::processAsset::downloadFile] err:#{err}, status:#{status}"

    switch status
      when 404
        uploadAsset(fileName, contentLocal, next)

      when 200
        # file exist on cdn, skip
        unless settings.UPLOAD_NEWLY_ASSET
          console.log "[upsyncer::processAsset::upload] skip asset:#{fileName}"
          next null

        sumRemote = checksum(contentRemote)
        # NOTE:
        #   contentRemote is binary data presented in String!
        # ty 2013-08-04

        if sumRemote is sumLocal
          console.log "[upsyncer::processAsset::upload] ignore identical asset:#{fileName}"
          next null
        else
          console.log "[upsyncer::processAsset::upload] upload diff asset:#{fileName}, lengthLocal:#{contentLocal.length}, lengthRemote:#{contentRemote.length}, iden:#{contentLocal.length is contentRemote.length}, sumLocal:#{sumLocal}, sumRemote:#{sumRemote}"
          #console.log "[upsyncer::method] contentLocal:#{Buffer.isBuffer(contentLocal)}"
          #console.log "[upsyncer::method] contentRemot:#{typeof(contentRemote)}"
          uploadAsset(fileName, contentLocal, next)

      else
        # unrecoginsed status code
        next("unrecoginsed status code:#{status}, fileName:#{fileName}")

    return

  return

# process an individual asset
processAssetNoComprison = (fileName, next)->
  console.info "[upsyncer::processAssetNoComprison] progress:#{++countProgress}/#{countAssets} - fileName:#{fileName}"

  client.checkFileExistence fileName, (err, isExist) ->
    console.log "[upsyncer::processAssetNoComprison] err:#{err}, isExist:#{isExist}, fileName:#{fileName}"

    console.trace() if err?
    if isExist
      console.log "[upsyncer::processAssetNoComprison] skip existing asset:#{fileName}"
      next(null)
      return
    else
      fullPath = "#{assetsKV[fileName]}/#{fileName}"
      uploadAsset(fileName, fs.readFileSync(fullPath), next)


    return

  return

# report working results
generateResult = (err, results)->
  ids = []
  for entry in results
    if entry? and entry.fileName?
      ids.push entry.fileName

  unless p.testDrive
    console.info "[upsyncer::generateResult] SYNC COMPLETE. revision sensitive:#{settings.REVISION_SENSITIVE}, #{ids.length} asset uploaded:#{ids}"
  else
    console.info "[upsyncer::generateResult] CHECKING COMPLETE. revision sensitive:#{settings.REVISION_SENSITIVE}, #{ids.length} asset should be synced:#{ids}"

  process.exit(0)
  return

## starting job
console.log "[cdn-syncer::start] find all sgf files from #{settings.LOCAL_DEPOT_ROOT}"

# listing assets files
walker = walk.walk(settings.LOCAL_DEPOT_ROOT, settings.WALK_OPTIONS)

walker.on "file", (root, fileStats, next) ->
  fileName = fileStats.name
  #console.log "[cdn-syncer::on file] name:#{fileName}, root:#{root}"
  #console.dir fileStats

  #console.log "~~~~~p.afterTimestamp:#{p.afterTimestamp}, fileStats.mtime.getTime():#{fileStats.mtime.getTime()}"
  #console.log "~~~~~settings.IGNORE_ASSET_MODIFIED_BEFORE:#{settings.IGNORE_ASSET_MODIFIED_BEFORE}, fileStats.mtime.getTime():#{fileStats.mtime.getTime()}"

  if isNaN(settings.IGNORE_ASSET_MODIFIED_BEFORE) or fileStats.mtime.getTime() > settings.IGNORE_ASSET_MODIFIED_BEFORE
    unless settings.REGEX_FILE_NAME
      assetsKV[fileName] = root
    else
      if settings.REGEX_FILE_NAME.test(fileName)
        assetsKV[fileName] = root
      else
        console.log "[cdn-syncer::on file] ignore invalid asset:#{fileName}"

  next()
  return

walker.on "errors", (root, nodeStatsArray, next) ->
  console.error "[cdn-syncer::on error] #{arguments}"
  process.exit(1)
  return

walker.on "end", ->
  assetsList = _.keys assetsKV
  countAssets = assetsList.length
  countProgress = 0

  console.log "[cdn-syncer::list file] file #{countAssets} assets, time spent:#{Date.now() - startAt} ms"
  #process.exit(0)

  processer = if settings.REVISION_SENSITIVE then processAsset else processAssetNoComprison

  if settings.PARALLELY
    # the faster way
    async.map(assetsList, processer, generateResult)
  else
    # series way for easy error checking
    async.mapSeries(assetsList, processer, generateResult)

  return



