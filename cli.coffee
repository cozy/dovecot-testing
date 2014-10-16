`#!/usr/bin/env node
`

Imap = require 'imap'
{exec} = require 'child_process'
program = require 'commander'
inquirer = require 'inquirer'

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

sayDone = (err) ->
    if err
        console.log err.stack or err
        process.exit 1
    else
        console.log "DONE"


program
   .version require('./package.json').version

program.command 'setup'
    .description 'setup a dovecot environment'
    .action ->
        DovecotTesting.setupEnvironment sayDone

program.command 'changeuidvalidity'
   .description 'ensure we start with a clean state'
   .action ->
        DovecotTesting.changeSentUIDValidity sayDone

program.command 'clean'
   .description 'ensure we start with a clean state'
   .action ->
        DovecotTesting.forcedCleanState sayDone

program.command 'save'
   .description 'bring back the changes to this directory'
   .action ->
        DovecotTesting.saveChanges sayDone

program.command 'import'
    .description 'import one mail'
    .action () ->

        rollback = (err, li, ri) ->
            li?.end()
            ri?.end()
            return console.log err.stack or err

        DovecotTesting.forcedCleanState (err) ->
            return console.log err if err

            openConnection localConfig, (err, localImap) ->
                return callback err if err
                console.log "opened local"

                userInputConnection (err, remoteConfig) ->
                    return rollback err, localImap, null if err

                    openConnection remoteConfig, (err, remoteImap) ->
                        return rollback err, localImap, remoteImap if err

                        pickBox 'choose a box', remoteImap, (err) ->
                            return rollback err, localImap, remoteImap if err

                            pickBox 'copy messages to', localImap, (err) ->
                                return rollback err, localImap, remoteImap if err

                                save = ->
                                    DovecotTesting.saveChanges (err) ->
                                        rollback err or 'DONE', localImap, remoteImap

                                do oneImport = ->

                                    pickUID (err, {uid}) ->
                                        return rollback err, localImap, remoteImap if err
                                        return save() unless uid

                                        copyOneMail localImap, remoteImap, uid, (err) ->
                                            return rollback err, localImap, remoteImap if err

                                            askContinue (err, {finished}) ->
                                                if not finished then oneImport()
                                                else save()


program.parse process.argv



userInputConnection = (callback) ->
    inquirer.prompt [
        { name: 'host', message: 'Imap host', default: 'imap.gmail.com' }
        { name: 'port', message: 'Imap port', default: '993' }
        { name: 'tls', message: 'Imap use tls', type:'confirm', default: true}
        { name: 'user', message: 'Imap username (xxxxx@gmail.com)'}
        { name: 'password', message: 'Imap password', type:'password'}
    ], callback.bind null, null

pickBox = (which, imap, callback) ->
    imap.getBoxes (err, boxes) ->
        options = []
        do flatten = (children = boxes, path = '') -> for name, box of children
            flatten box.children, path + name + box.delimiter
            if 'NoSelect' not in box.attribs then options.push path + name

        inquirer.prompt [
            type: 'list', name: 'box', choices: options, message: "Choose #{which} box"

        ], ({box}) ->
            imap.openBox box, callback

pickUID = (callback) ->
    inquirer.prompt [
        {name: 'uid', message: 'UID of the message'}
    ], callback.bind null, null

askContinue = (callback) ->
    inquirer.prompt [
        {name: 'finished', message: 'Are you done', type:'confirm', default:false}
    ], callback.bind null, null


openBoxes = (localConfig, localBox, remoteConfig, remoteBox, callback) ->

        openConnection remoteConfig, (err, remoteImap) ->
            return callback err, localImap if err
            console.log "opened remote"


            localImap.openBox localBox, (err) ->
                return callback err, localImap, remoteImap if err
                console.log "box local", localBox

                remoteImap.openBox remoteBox, (err) ->
                    return callback err, localImap, remoteImap if err
                    console.log "box remote", remoteBox

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

