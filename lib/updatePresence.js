var config = require('./../config');

var devices = require('./database').devices;

module.exports = function(socket) {
  devices.update({socketid: socket}, {$set: {online: false}});
};
