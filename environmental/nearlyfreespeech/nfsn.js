var NfsnClient = require('nfsn-client');
// You'll need your own values for login/apiKey
var client = new NfsnClient({
  login: 'haxwell',
  apiKey: 'GP3M1IPbPymdlaCw'
});

// Check if there's a command-line argument provided
if (process.argv.length <= 3) {
  console.log('')
  console.log('This script will remove an A type DNS record for the given subdomain, and replace it with one using the given IP address.');
  console.log('')
  console.log('Usage: node script.js dmpj-backend-api.staging 3.43.221.198');
  console.log('')
  process.exit(1);
}

// Get the parameter from command-line arguments
var parameter = process.argv[2];
var data = undefined;

client.dns.listRRs('savvato.com', {type: 'A'}, function(err, resp) {
  if (!err) {
//    console.log(JSON.stringify(resp, undefined, 2));

    data = resp.filter(obj => obj.name == parameter);

    if (data) {

  //    console.log(JSON.stringify(data, undefined, 2));

      client.dns.removeRR('savvato.com', data[0], function(err, resp) {
        if (!err) {
    //      console.log(JSON.stringify(resp, undefined, 2));

          data[0]["data"] = process.argv[3];

          client.dns.addRR('savvato.com', data[0], function(err, resp) {
            if (!err) {
              console.log('Successfully updated A type DNS record for ' + data[0]["name"] + ' to ' + data[0]["data"]);
            } else {
              console.error('Error adding an A record:', err.message);
            }
          });
        } else {
          console.error('Error:', err.message);
        }
      });
    }
  } else {
    console.log('Error, could not find DNS info for ' + parameter);
  }
})
