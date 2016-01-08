#!/usr/bin/env coffee
`#!/usr/bin/env node`

{exec} = require 'child_process'
{Socket} = require 'net'
tls = require 'tls'

module.exports = DovecotTesting = {}

run = (cmd, callback) ->
    exec cmd, (err, stdout, stderr) ->
        console.log stdout
        console.log stderr if err
        callback err

waitDovecotUp = (callback, i = 0) ->

    # timeout at 10 attempts
    return callback new Error('dovecot is broken') if i is 20
    if i is 0 then process.stdout.write 'Waiting for dovecot to start'
    else process.stdout.write '.'

    socket = new Socket()
    socket.on 'data', -> #drop it
    socket.once 'connect', ->
        process.stdout.write "\n"
        console.log "Dovecot took #{i}s to start"
        socket.destroy()
        callback null

    socket.once 'error', (err) ->
        return callback err if err.code isnt 'ECONNREFUSED'
        # dovecot not started yet
        try socket.destroy()
        setTimeout ->
            waitDovecotUp callback, i + 1
        , 1000

    socket.connect 993, DovecotTesting.serverIP()

if process.env.INVAGRANT? then RUN_IN_VAGRANT = process.env.INVAGRANT
else RUN_IN_VAGRANT = not process.env.TRAVIS and process.env.USER isnt 'vagrant'

DovecotTesting.serverIP = ->
    if RUN_IN_VAGRANT then '172.31.1.2' else '127.0.0.1'

DovecotTesting.isVagrantUp = (done) ->
    exec "cd #{__dirname}/vagrant && vagrant status"
    , (err, stdout, stderr) ->
        if err and err.code is 127
            return done new Error('you need to install vagrant')
        else if err
            console.log stdout
            return done new Error('failed to vagrant status')
        else
            return done null, ~stdout.indexOf 'running'

DovecotTesting.changeSentUIDValidity = (done) ->
    @timeout? 300000
    cmd = 'sudo /bin/bash /resources/Scripts/Uidvaliditychange.sh'

    if RUN_IN_VAGRANT
        cmd = "cd #{__dirname}/vagrant && vagrant ssh --command \"#{cmd}\""

    run cmd, (err) ->
        if err
            return done new Error('failed to change UID')

        # let dovecot time to start
        waitDovecotUp done

DovecotTesting.setupEnvironment = (done) ->
    @timeout? 300000

    if RUN_IN_VAGRANT
       console.log 'Starting Vagrant Provisioning'
       DovecotTesting.isVagrantUp (err, vagrantIsUp) ->
            cmd = if vagrantIsUp then 'vagrant provision'
            else 'vagrant up --provision'

            run "cd #{__dirname}/vagrant && " + cmd, (err) ->
                if err
                    return done new Error('failed to start Dovecot')

                # let dovecot time to start
                waitDovecotUp done

    else
        console.log 'Starting Local Provisioning'
        run """
            sudo cp -Rp #{__dirname}/resources /resources &&
            sudo /bin/bash /resources/Scripts/Provision.sh &&
            sudo /bin/bash /resources/Scripts/SSL.sh
        """
        , (err) ->
            if err
                return done new Error('failed to start Dovecot')

            # let dovecot time to start
            waitDovecotUp done

DovecotTesting.forcedCleanState = (done) ->
    @timeout? 30000
    cmd = """
        sudo rm -rf /resources/ &&
        sudo rm -rf /home/testuser/Maildir/
    """

    if RUN_IN_VAGRANT
        cmd = "cd #{__dirname}/vagrant && " +
            " vagrant ssh --command \"sudo rm -rf /home/testuser/Maildir/\""

    run cmd, (err) ->
        if err then return done new Error('cant rimraf')

        DovecotTesting.setupEnvironment done



DovecotTesting.saveChanges = (done) ->
    copy = if RUN_IN_VAGRANT then 'scp -r vagrant@172.31.1.2:'
    else 'sudo cp -Rp '

    run "#{copy}/home/testuser/Maildir #{__dirname}/resources/", done



unless module.parent

    commands =
        setup: 'setupEnvironment'
        clean: 'forcedCleanState'
        save: 'saveChanges'
        ip: 'serverIP'

    process.argv

    DovecotTesting.setupEnvironment ->
        console.log "ALL SET, IN VAGRANT =", RUN_IN_VAGRANT

