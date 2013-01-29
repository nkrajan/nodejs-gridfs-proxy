require "js-yaml"
mongodb = require "mongodb"
url = require "url"
http = require "http"

class GridfsProxyServer
  config = {}
  database = null

  run: ->
    console.log "Starting server..."

    @config = @loadConfig "./config/server.yml"

    server = new mongodb.Server @config.gridfs.host, @config.gridfs.port,
      { auto_reconnect: @config.gridfs.auto_reconnect }

    @database = new mongodb.Db @config.gridfs.database, server, { w: 0, native_parser: true }

    @database.open @onDatabaseOpen

  onDatabaseOpen: (error, database) =>
    if error != null
      console.log "Error connecting to mongodb: ", error
      process.exit(1)
    else
      console.log "DB connection ok, starting server on " + @config.listen.host + ", port " + @config.listen.port
      server = http.createServer this.onRequest
      server.listen @config.listen.port, @config.listen.host

  onRequest: (request, response) =>
    pathObj = url.parse request.url
    path = pathObj.path.substring 1
    console.log "-> Requested path " + path
    gridStore = new mongodb.GridStore @database, path, 'r'
    gridStore.open (error, file) =>
      if error
        if error.message == path + ' does not exist'
          response.writeHead 404, { "Content-Type": "text/plain" }
          response.end "File not found"
          console.log "Not found"
        else
          response.writeHead 500, { "Content-Type": "text/plain" }
          response.end "Internal server error"
          console.log "Internal server error", error
      else
        if request.headers['if-none-match'] == file.fileId.toString()
          response.writeHead 304, {
            "Etag": file.fileId,
            "Last-Modified": file.uploadDate.toGMTString()
          }
          response.end ""
          console.log "Returned 304 response"
        else
          # plain response
          response.writeHead 200, {
            "Content-Type": file.contentType || @guessMime file.filename
            "Etag": file.fileId,
            "Last-Modified": file.uploadDate.toGMTString()
          }
          fileStream = file.stream true
          fileStream.on "data", (data) =>
            if @config.php_fix
              if data.length > 4 and (data[2] == 0x02 or data[2] == 0x00) and data[3] == 0x00
                console.log "Fixing unsupported BinaryType 2"
                response.write data.slice 4
              else
                response.write data
            else
              response.write data
          fileStream.on "end", () =>
            response.end ""
            console.log "Sent response successfully"

  guessMime: (filename) ->
    if filename.match /\.jpg$/i
      return "image/jpeg"
    if filename.match /\.gif$/i
      return "image/gif"
    if filename.match /\.png$/i
      return "image/png"
      
    "binary/octet-stream"

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