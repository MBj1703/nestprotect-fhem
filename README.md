# nestprotect-fhem

Das Modul einfach in den ./FHEM Ordner kopieren, evtl. Rechte anpassen und dann in fhem reload 39_nestprotect.pm eingeben.

Um das Modul zu nutzen, sind ein paar Dinge im Vorfeld durchzuführen:

1. einen Developer Account bei Nest anlegen (developers.nest.com)
2. im Dev Account ein Produkt anlegen und Redirect URI leer lassen
3. Permissions auf Smoke+CO Alarm geben

Danach könnt ihr auf euer Produkt klicken und bekommt dort die Product ID, das Product Secret und die Authorization URL.
Die Product ID und das Product Secret brauchen wir später nochmal.

Jetzt muss man einen PIN kreieren, dazu einfach die Authorization URL im Browser eingeben.
Danach kommt eine Works with Nest Seite, dort bitte Annehmen klicken, danach wird der PIN angezeigt.

Nun kann man in fhem das Device anlegen: define NAME nestprotect PIN
Als nächstes bitte die zwei nötigen Attribute anlegen:
1. ProductID = Product ID von eurem Produkt auf der Developer Konsole 
2. ProductSecret = Product Secret von eurem Produkt auf der Developer Konsole

Jetzt muss man sich mit set Token einen Token von der API holen.
Sobald der Token als Reading vorhanden ist, ist man mit der Konfig fertig.

Wer möchte, kann jetzt einfach ein get update machen und sollte nach einem kleinen Augenblick die Readings seines NestProtect erhalten.

Da ich noch keinen Interval eingebaut habe (obwohl es das Attribut gibt), legt das Modul einen at mit ($name.Poll) an, der alle 5 Minuten ein get update macht. Dies kann von jedem natürlich geändert werden und ist nur ein Workarround.

Als nächstes kann man sich z.B. einen DOIF oder notify einrichten, der auf die Events reagiert.
Es werden Events für online, last_seen, battery, co_status und smoke_status erzeugt.

Folgende Events sind möglich:

battery
ok   Battery level ok
replace   Battery level low, should be replaced

co_status
ok   Normal operation
warning   Detection of rising CO levels
emergency   CO levels too high, user should exit the home

smoke_status
ok   Normal operation
warning   Detection of rising smoke levels
emergency   Smoke levels too high, user should exit the home

online
1     NetsProtect ist online/hat Internet
0     NetsProtect ist offline/kein Internet

Benutzung ohne Gewähr!
