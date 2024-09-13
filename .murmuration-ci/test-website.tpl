cat << EOF >> test-website.sh
#!/bin/sh
echo 'Testing root page:'
curl -f -i 'https://${parlai_website_endpoint}/'
echo  
echo 'Testing root css:'
curl -f -i 'https://${parlai_website_endpoint}/static/css/parlai.css'
echo
echo 'Testing docs page'
curl -f -i 'https://${parlai_website_endpoint}/docs/'
echo
echo 'Testing docs css'
curl -f -i 'https://${parlai_website_endpoint}/docs/_static/css/parlai_theme.css'

EOF