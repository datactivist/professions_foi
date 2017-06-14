// scrape_site.js
var webPage = require('webpage');
var page = webPage.create();
var fs = require('fs');
var path = 'temppage.html'

page.open('https://programme-candidats.interieur.gouv.fr/elections/1/departments/6/circonscriptions/6', function (status) {
var content = page.content;
fs.write(path,content,'w')
phantom.exit();
});
