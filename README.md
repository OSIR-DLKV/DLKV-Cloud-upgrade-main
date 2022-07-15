# DLKV Cloud upgrade
OK napravio sam privatni github repozitorij za spremanje svih nadogradnji i da probamo bar nekako spriječit pregazivanje jedni drugima. Ne znam za neki besplatni SVN pa nek bude ovako. Dodavat ću stvari s vremenom.

Ako ima netko iskustva s git-om nek slobodno podijeli (ispravi moje bedastoće:)) ili napravi neki crash course.

Malo je drukčiji od SVN-a u smislu decentralizacije. Ako sam dobro shvatio imaš main repo kojeg mozes klonirat da dobijes codebase, a onda kad radiš radiš neki branch u kojem radiš svoje promjene i commitaš lokalno. Kad završiš šalješ svoj branch na merge u glavni.
Nitko nam ne brani da radimo na main branchu. 

osnovne naredbe

git clone pa_neki_url
git add .  => dodaj sve fileove u repozitorij. Ovo mora ić za svaki novi file (uostalom kao za SVN)
git commit -m 'neka poruka uz commit'
git fetch => ne znam čemu služi zasad, čini mi se slično kao pull, al evo ne znam :)
git pull => povuče promjene iz remote repozitorija
git push ide kad želiš commit poslati svima na main repozitorij


1. Korak, otvorite account na github.com
2. Javite mi account pa ću vas dodat pod OSIR-ERPIS organizaciju (ja sam kreirao pod zoran.kovac@osir-erpis.eu)
3. Treba kreirati personal token jer vam neće nikako klonirat repozitorij: https://stackoverflow.com/questions/2505096/clone-a-private-repository-github

4. Jedina naredba koja je meni klonirala repozitorij je:

git clone https://KOPIRAJ_SVOJ_TOKEN_OVDJE@github.com/OSIR-DLKV/DLKV-Cloud-upgrade-main.git

4. postoji github desktop aplikacija za commitanje i hendlanje repozitorija. Meni je u početku bila konfuzna pa sam koristio git bash CLI.
Al evo link za one koji hoće neki client

https://desktop.github.com/

5. najbolje je možda tortoise git jer smo navikli na SVN:

https://tortoisegit.org/download/

Za tortoise git skinite: https://gitforwindows.org/ 


