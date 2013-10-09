#!/bin/sh

ln -s /usr/local/bin/bash /bin/bash

# http://wiki.opscode.com/display/chef/Installing+Omnibus+Chef+Client+on+Linux+and+Mac
curl -L https://www.opscode.com/chef/install.sh | /usr/local/bin/bash

rm /bin/bash

exit
