var http = require('http'),
    mongodb = require('mongodb'),
    url = require('url'),
    config = require('yaml-config');

console.log('Starting gridfs proxy server...');

