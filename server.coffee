require "js-yaml"
mongodb = require "mongodb"
url = require "url"
http = require "http"

class GridfsProxyServer
  config = {}

  run: ->
    console.log "Starting server..."

    @config = @loadConfig "./config/server.yml"

    server = new mongodb.Server @config.gridfs.host, @config.gridfs.port,
      { auto_reconnect: @config.gridfs.auto_reconnect}

    database = new mongodb.Db @config.gridfs.database, server, { safe: false }

    database.open @onDatabaseOpen

  onDatabaseOpen: (error, database) =>
    if error != null
      console.log "Error connecting to mongodb: ", error
      process.exit(1)
    else
      console.log "DB connection ok, starting server on " + @config.listen.host + ", port " + @config.listen.port
      server = http.createServer this.onRequest
      server.listen @config.listen.port, @config.listen.host

  onRequest: (request, response) ->
    pathObj = url.parse request.url
    path = pathObj.path.substring 1
    console.log "Requested path " + path

  loadConfig: (file) ->
    config = require file
    env =  process.env.NODE_ENV || 'development'
    console.log 'Using "' + env + '" environment to load config ' + file

    # global and per-env settings
    settings = config['default'] || {}
    settings_env = config[env] || {}

    # merging
    settings = this.extend settings, settings_env

    return settings

  extend: (dest, from) ->
    props = Object.getOwnPropertyNames from
    props.forEach (name) ->
      if name in dest and typeof dest[name] == 'object'
        extend dest[name], from[name]
      else
        newDest = Object.getOwnPropertyDescriptor from, name
        Object.defineProperty dest, name, newDest

    return dest

# start server
gridfsProxyServer = new GridfsProxyServer
gridfsProxyServer.run()