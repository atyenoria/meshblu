_            = require 'lodash'
bcrypt       = require 'bcrypt'
util         = require '../../lib/util'

describe 'simpleAuth', ->
  beforeEach ->
    @sut = require '../../lib/simpleAuth'

  it 'should exist', ->
    expect(@sut).to.exist

  describe 'canDiscover', ->
    it 'should exist', ->
      expect(@sut.canDiscover).to.exist

    describe 'when fromDevice is undefined', ->
      it 'should return false', (next) ->
        @sut.canDiscover(undefined, uuid: 1, (error, permission) =>
          expect(permission).to.be.false
          next()
        )

    describe 'when toDevice is undefined', ->
      it 'should return false', (next) ->
        @sut.canDiscover( uuid: 1, undefined, (error, permission) =>
          expect(permission).to.be.false
          next()
        )

    describe 'when fromDevice is the same device as toDevice', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 1
      it 'should return true', (next) ->
        @sut.canDiscover( @fromDevice, @toDevice, (error, permission) =>
          expect(permission).to.be.true
          next()
        )

    describe 'when fromDevice is a different device than toDevice', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2

      it 'should return false', (next) ->
        @sut.canDiscover( @fromDevice, @toDevice, (error, permission) =>
          expect(permission).to.be.true
          next()
        )

      describe 'when toDevice has a discoverWhitelist that doesn\'t have fromDevice\'s uuid', ->
        beforeEach ->
          @toDevice.discoverWhitelist = [5]

        it 'should return false', (next) ->
          @sut.canDiscover( @fromDevice, @toDevice, (error, permission) =>
            expect(permission).to.be.false
            next()
          )

      describe 'when toDevice has a descoverWhitelist containing "*"', ->
        beforeEach ->
          @toDevice.discoverWhitelist = ['*']

        it 'should return true', (next)->
          @sut.canDiscover( @fromDevice, @toDevice, (error, permission) =>
            expect(permission).to.be.true
            next()
          )

      describe 'when toDevice has a descoverWhitelist is "*"', ->
        beforeEach ->
          @toDevice.discoverWhitelist = '*'

        it 'should return true', (next)->
          @sut.canDiscover( @fromDevice, @toDevice, (error, permission) =>
            expect(permission).to.be.true
            next()
          )


    describe 'when fromDevice owns toDevice', ->
      beforeEach ->
        @fromDevice = owner: 4321, uuid: 1234
        @toDevice = owner: 1234, uuid: 2222

      it 'should return true', (next)->
        @sut.canDiscover( @fromDevice, @toDevice, (error, permission) =>
          expect(permission).to.be.true
          next()
        )

    describe 'when fromDevice is in the toDevice\'s discoverBlacklist', ->
      beforeEach ->
        @fromDevice = uuid: 1234
        @toDevice = uuid: 2222, discoverBlacklist: [ 1234 ]

      it 'should return false', (next) ->
        @sut.canDiscover( @fromDevice, @toDevice, (error, permission) =>
          expect(permission).to.be.false
          next()
        )


  describe 'canConfigure', ->
    it 'should exist', ->
      @getDatabaseForDevice = (device) =>
        {
          devices:
            findOne: (query, callback) =>
              callback null,device
        }

      @sut.database = @getDatabaseForDevice()
      expect(@sut.canConfigure).to.exist

    describe 'when fromDevice is undefined', ->
      it 'should return false', (next) ->
        @sut.canConfigure( undefined, uuid: 1, (error, permission) =>
          expect(permission).to.be.false
          next()
        )

    describe 'when toDevice is undefined', ->
      it 'should return false', (next) ->
        @sut.canConfigure( uuid: 1, undefined, (error, permission) =>
          expect(permission).to.be.false
          next()
        )

    describe 'when toDevice is the same as fromDevice', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 1

      it 'should return true', (next) ->
        @sut.canConfigure( @fromDevice, @toDevice, (error, permission) =>
          expect(permission).to.be.true
          next()
        )

    describe 'when toDevice is different from fromMessage, and has sent a message that includes the token of toDevice', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2, tokens: [
          {hash: '0'}
          {hash: '1'}
          {hash: '2'}
          {hash: bcrypt.hashSync('5555',1)}
        ]
        @message = token: '5555'
        @sut.database = @getDatabaseForDevice @toDevice
      it 'should return true', (next) ->
        @sut.canConfigure( @fromDevice, @toDevice, @message, (error, permission) =>
          expect(permission).to.be.true
          next()
        )

    describe 'when toDevice is different from fromMessage, and has sent a message that includes a random uuid', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2, tokens: [
          {hash: bcrypt.hashSync('69',1)}
          {hash: 0}
          {hash: 0}
         ]
        @message = token: '5555'
        @sut.database = @getDatabaseForDevice @toDevice

      it 'should return false', (done) ->
        @sut.canConfigure( @fromDevice, @toDevice, @message, (error, permission) =>
          expect(permission).to.be.false
          done()
        )

    describe 'when the owner of a device sends a configure command, but gets the token wrong', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2, tokens: [bcrypt.hashSync('69',1)], owner: 1
        @message = token: '5555'
        @sut.database = @getDatabaseForDevice @toDevice

      it 'should do it anyway', (next) ->
        @sut.canConfigure( @fromDevice, @toDevice, @message, (error, permission) =>
          expect(permission).to.be.true
          next()
        )

    describe 'when a device is unclaimed, and exists on the same lan as the configuring device', ->
      beforeEach ->
        @fromDevice = uuid: 1
        @toDevice = uuid: 2
        util.sameLAN = sinon.stub().returns true

      it 'should return true', (next) ->
        @sut.canConfigure( @fromDevice, @toDevice, (error, permission) =>
          expect(permission).to.be.true
          next()
        )

    describe 'when a device is in the configureWhitelist', ->
      beforeEach (next) ->
        @fromDevice = uuid: 1
        @sut.checkLists = sinon.stub().returns true
        @toDevice = uuid: 8, configureWhitelist: [7], configureBlacklist: [6]
        @sut.canConfigure(@fromDevice, @toDevice, (error, permission) =>
          @result = permission
          next()
        )

      it 'should call checkLists', ->
        expect(@sut.checkLists).to.have.been.called

      it 'should call checkLists', ->
        expect(@sut.checkLists).to.have.been.calledWith @fromDevice, @toDevice, @toDevice.configureWhitelist, @toDevice.configureBlacklist, false

      it 'should have a result of true', ->
        expect(@result).to.be.true

    describe 'when a different device is in the configureWhitelist', ->
      beforeEach (next)->
        @sut.checkLists = sinon.stub().returns false
        @sut.canConfigure(null, null, (error, permission) =>
          @result = permission
          next()
        )

      it 'should have a result of false', ->
        expect(@result).to.be.false

    describe 'when a different device is in the configureWhitelist', ->
      beforeEach (next) ->
        @fromDevice = uuid: 7
        @toDevice = uuid: 8, configureWhitelist: [5], configureBlacklist: [6]
        @sut.checkLists = sinon.stub().returns false
        @sut.canConfigure(@fromDevice, @toDevice, (error, permission) =>
          @result = permission
          next()
        )

      it 'should call checkLists', ->
        expect(@sut.checkLists).to.have.been.calledWith @fromDevice, @toDevice, @toDevice.configureWhitelist, @toDevice.configureBlacklist, false

    describe 'when a device is unclaimed, and exists on a different lan than the configuring device', ->
      beforeEach (next) ->
        @fromDevice = uuid: 1, ipAddress: '127.0.0.1'
        @toDevice = uuid: 2, ipAddress: '192.168.0.1'
        util.sameLAN = sinon.stub().returns false
        @sut.canConfigure( @fromDevice, @toDevice, (error, permission) =>
          @result = permission
          next()
        )

      it 'should return false', ->
        expect(@result).to.be.false

      it 'should call sameLan with the ipAddresses of both devices', ->
        expect(util.sameLAN).to.have.been.calledWith '127.0.0.1', '192.168.0.1'
