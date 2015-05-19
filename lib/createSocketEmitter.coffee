config = require('../config')
redis = require('./redis')
subEvents = require('./subEvents')

# if config.redis and config.redis.host
#   emitter = require('socket.io-emitter')(redis.client)

if config.useMongoIOStore
  mongoEmitter = require('socket.io-mongodb-emitter')
  emitter = mongoEmitter host: 'localhost', port: 27017, db: 'mubsub'

module.exports = (io, ios) ->
  if emitter?
    return (channel, topic, data) ->
      emitter.in(channel).emit topic, data

  if io
    return (channel, topic, data) ->
      io.sockets.in(channel).emit topic, data
      if ios
        ios.sockets.in(channel).emit topic, data
      #for local http streaming:
      subEvents.emit channel, topic, data
