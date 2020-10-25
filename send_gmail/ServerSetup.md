# Configure Firewall
Haven't done this, should I? Maybe following [this](http://www.linuxhomenetworking.com/wiki/index.php/Quick_HOWTO_:_Ch14_:_Linux_Firewalls_Using_iptables#.X5WQSFNKjOQ)

# Email guides
- https://www.linode.com/docs/guides/email-with-postfix-dovecot-and-mysql/
- https://www.linode.com/docs/guides/running-a-mail-server/
- https://poolp.org/posts/2019-09-14/setting-up-a-mail-server-with-opensmtpd-dovecot-and-rspamd/

Note that Gilles, the man behind poolp is a primary developer behind OpenSMTP and there have been some pretty serious [vulnerabilities](https://en.wikipedia.org/wiki/OpenSMTPD#History)

# G-mail API (because I'm a corporate shill)
Get your [credentials.json](https://developers.google.com/gmail/api/quickstart/python)
```bash
pip install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib
```

run `quickstart.py` to authenticate with google. If you want to change your permissions, e.g. read mail, delete token.pickle on the server, change your SCOPE and re-run.

run `send.py arbitrary to subject msg` to send a message from `masonunvagun@gmail.com`.
