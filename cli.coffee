`#!/usr/bin/env node
`

Imap = require 'imap'
{exec} = require 'child_process'
program = require 'commander'

DovecotTesting = require './index'
iconv = require 'iconv-lite'
iconv.extendNodeEncodings();

localConfig =
    user: "testuser"
    password: "applesauce"
    host: DovecotTesting.serverIP()
    port: 993
    tls: true
    # debug: console.log.bind console, 'local'
    tlsOptions: rejectUnauthorized: false


program
   .version require('./package.json').version

program.command 'setup'
    .description 'setup a dovecot environment'
    .action ->
        DovecotTesting.setupEnvironment -> console.log "DONE"

program.command 'clean'
   .description 'ensure we start with a clean state'
   .action ->
        DovecotTesting.forcedCleanState -> console.log "DONE"

program.command 'save'
   .description 'bring back the changes to this directory'
   .action ->
        DovecotTesting.saveChanges -> console.log "DONE"

program.command 'import <url> <frombox> <uid> <tobox>'
    .description 'import one mail'
    .action (url, from, uid, to) ->
        parsed = require('url').parse url
        [user, pass] = parsed.auth.split ':'

        DovecotTesting.forcedCleanState (err) ->
            return console.log err if err

            remoteConfig =
                user: user
                password: pass
                host: parsed.host
                port: parsed.port
                tls: parsed.protocol is 'imaps:'

            rollback = (li, ri, err) ->
                li?.end()
                ri?.end()
                return console.log err.stack or err

            openBoxes localConfig, to, remoteConfig, from, (err, li, ri) ->
                return rollback li, ri, err if err

                copyOneMail li, ri, uid, (err) ->
                    return rollback li, ri, err if err
                    rollback li, ri, 'DONE'

program.parse process.argv



openBoxes = (localConfig, localBox, remoteConfig, remoteBox, callback) ->
    openConnection localConfig, (err, localImap) ->
        return callback err if err

        openConnection remoteConfig, (err, remoteImap) ->
            return callback err, localImap if err

            localImap.openBox from, (err) ->
                return callback err, localImap, remoteImap if err

                remoteImap.openBox to, (err) ->
                    return callback err, localImap, remoteImap if err

                    callback null, localImap, remoteImap


openConnection = (config, callback) ->
    imap = new Imap config
    imap.once 'error', (err) -> callback err
    imap.once 'ready', -> callback null, imap
    imap.connect()

getMail = (imap, id, callback) ->
    f = imap.fetch id, bodies: ''
    f.on 'error', (err) -> callback err
    f.on 'message', (msg) ->
        msg.on 'error', (err) -> callback err
        msg.on 'body', (stream) ->
            parts = []
            stream.on 'data', (d) -> parts.push d
            stream.on 'end', -> callback null, Buffer.concat parts

copyOneMail = (local, remote, id, callback) ->
    getMail remote, id, (err, buffer) ->
        console.log "COPY MAIL-#{id} HAS LENGTH = ", buffer.length
        local.append buffer, {}, (err) ->
            return callback err if err
            setTimeout (-> callback null), 5000

copyOneBox = (li, local, ri, remote, ids, callback) ->
    li.openBox local, false, (err) ->
        return console.log err if err

        ri.openBox remote, false, (err) ->
            return console.log err if err

            asyncLoop ids, (id, cb) ->
                copyOneMail li, ri, id, cb
            , callback

