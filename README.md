# dovecot-testing

This is a port of [tedious/DovecotTesting](https://github.com/tedious/DovecotTesting)
with a node interface and support for usage inside a vagrant

## Install

```
git clone https://github.com/cozy/dovecot-testing
cd dovecot-testing
npm link
```

## Use in JS
```javascript
    DovecotTesting = require('dovecot-testing');
    DovecotTesting.setupEnvironment(function(err){})

    imapOptions = {
        user: "testuser",
        password: "applesauce",
        host: DovecotTesting.serverIP(),
        port: 993,
        tls: true,
        tlsOptions: {rejectUnauthorized: false}
    }

    DovecotTesting.changeSentUIDValidity(function(err){})
```

## Use the CLI

Start a dovecot

    dovecot-testing setup

Import a buggy email into the test suite (buggy emails PR very welcome)
Example : import email UID#356 from [Gmail]/All messages into INBOX

    dovecot-testing import imaps://aenario_at_gmail.com:password@imap.gmail.com:993 '[Gmail]/All messages' 356 INBOX
    git add /resources/Maildir
    git diff #review changes
    git commit

## Tests

PR Welcomes

## License

MIT
