/* eslint-disable @typescript-eslint/no-var-requires,import/no-unresolved */
const fs = require('fs');
const idl = require('./target/idl/chick_bridge.json');

fs.writeFileSync('./app/src/idl.json', JSON.stringify(idl, null, 2));
