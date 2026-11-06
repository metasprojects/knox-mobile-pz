-- Spanish for the story (Core/Lang, 0.2.5): the templates (Story/Templates), the places and buildings texts name,
-- jobs, the family's names on your phone, and the lines the code writes itself (the journal, notes). Neutral Latin
-- American Spanish, "tú". The English line is the key, exactly as the code has it; [a|b] groups and {slots} stay
-- (tests/unit/test_lang.lua checks both). Place names keep their article: "a {place}" with "el motel" is tidied to
-- "al motel" (Lang.tidy).
local D = {
    -- Story/Templates: dead people's phones, before the news ---------------------------------------------------
    ["[Don't forget|Remember] Sunday dinner [hun|sweetie]. Bring {partner}"] =
        "[No olvides|Acuérdate de] la cena del domingo, [cariño|corazón]. Trae a {partner}",
    ["Cookout Sunday for the 4th. Bring {partner}"] = "Parrillada el domingo por el 4 de julio. Trae a {partner}",
    ["[u coming out friday|you still on for friday]? [Twiggy's|Spiffo's] at 9"] =
        "[vas a salir el viernes|sigue en pie lo del viernes]? [Twiggy's|Spiffo's] a las 9",
    ["fireworks at the river on the 4th?"] = "fuegos artificiales en el río el 4?",
    ["[running late|stuck in traffic] be there in 20"] = "[voy tarde|estoy en el tráfico] llego en 20",
    ["Can you cover [Thursday|Saturday] at {jobPlace}?"] = "¿Puedes cubrir el [jueves|sábado] en {jobPlace}?",
    ["[pick up milk|grab some bread] on the way home?"] = "[compras leche|traes pan] de camino a casa?",
    ["[did u call mom back|mom says call her]"] = "[ya le llamaste a mamá|mamá dice q la llames]",
    ["[Truck's fixed.|Got the truck running.] [Come get your tools|Your tools are in the shed]"] =
        "[Ya arreglé la camioneta.|Ya arranca la camioneta.] [Ven por tus herramientas|Tus herramientas están en el cobertizo]",
    ["[Your aunt called.|Grandma called.] [Call her back|She wants to hear from you]"] =
        "[Llamó tu tía.|Llamó la abuela.] [Llámala|Quiere saber de ti]",
    ["[we still on for saturday?|you coming saturday?] [i got tickets|bring cash]"] =
        "[sigue en pie lo del sábado?|vienes el sábado?] [ya tengo boletos|trae efectivo]",
    ["[cant make it tonight|gonna skip tonight], [sorry|rain check]"] = "[no puedo ir hoy|hoy no voy], [perdón|otro día]",
    ["[dinner at 7? i'll cook|want to get takeout? my treat]"] = "[cena a las 7? yo cocino|pedimos comida? yo invito]",
    ["Heads up: [staff|safety] meeting [Monday|Wednesday] at {jobPlace}"] =
        "Aviso: reunión [de personal|de seguridad] el [lunes|miércoles] en {jobPlace}",
    ["Reminder: inventory [Monday|Wednesday]. Don't be late"] = "Recordatorio: inventario el [lunes|miércoles]. No llegues tarde",
    ["[happy birthday!!|happy bday!!] [call me later|love ya]"] = "[feliz cumpleaños!!|feliz cumple!!] [llámame al rato|te quiero]",
    ["[Mowed your yard.|Fixed the porch light.] You owe me [a beer|lunch]"] =
        "[Te corté el pasto.|Arreglé la luz del porche.] Me debes [una cerveza|un almuerzo]",

    -- The news (July 4-5)
    ["did you see the news?? [people biting people|they keep saying its the flu]"] =
        "viste las noticias?? [gente mordiendo gente|siguen diciendo q es la gripe]",
    ["Are you watching WBLN? Call me"] = "¿Estás viendo WBLN? Llámame",
    ["[probably nothing|its just the flu thing] dont worry"] = "[seguro no es nada|es lo de la gripe] no te preocupes",
    ["All staff report to {jobPlace} [early|at 6]. No exceptions."] =
        "Todo el personal preséntese en {jobPlace} [temprano|a las 6]. Sin excepciones.",
    ["theres army trucks on [the highway|31W]"] = "hay camiones del ejército en [la carretera|la 31W]",
    ["[the pool's closed|they cancelled the game]. whats going on"] = "[cerraron la piscina|cancelaron el partido]. q está pasando",
    ["[Fill up the car.|Get gas while you can.] [Lines are long already.|Prices are going up.]"] =
        "[Llena el tanque.|Carga gasolina mientras puedas.] [Ya hay filas largas.|Los precios están subiendo.]",
    ["[my cousin says|heard from my cousin] the hospital in Louisville is [packed|turning people away]"] =
        "[mi primo dice|me dijo mi primo] q el hospital de Louisville está [lleno|rechazando gente]",
    ["[Due to current events|Because of the situation], we're [closing early today|on reduced hours]."] =
        "[Debido a los acontecimientos|Por la situación], [cerramos temprano hoy|tenemos horario reducido].",
    ["[grocery store is a zoo|no bread left anywhere]. [got what i could|got canned stuff]"] =
        "[el súper es un manicomio|no queda pan en ningún lado]. [agarré lo q pude|compré latas]",
    ["[Wash your hands|Don't let anyone in] and stay away from sick people"] =
        "[Lávate las manos|No dejes entrar a nadie] y aléjate de los enfermos",
    ["[did you hear sirens last night|helicopters all night]?"] = "[oíste las sirenas anoche|helicópteros toda la noche]?",

    -- The closure (July 6-9)
    ["they closed the bridge. [we cant get out|nobody in or out]"] = "cerraron el puente. [no podemos salir|nadie entra ni sale]",
    ["house phone's dead. knox telecom wont say why"] = "el teléfono de la casa no sirve. knox telecom no dice por qué",
    ["They say stay inside. Where are you???"] = "Dicen que nos quedemos adentro. ¿¿¿Dónde estás???",
    ["[cant get through to anyone|phones are jammed] im ok"] = "[no puedo comunicarme con nadie|las líneas están saturadas] estoy bien",
    ["We're closed until further notice. [Stay home.|Stay safe.]"] = "Cerramos hasta nuevo aviso. [Quédense en casa.|Cuídense.]",
    ["All leave is cancelled. [Report to {jobPlace} now.|Every shift is mandatory.]"] =
        "Se cancelan todos los permisos. [Preséntate en {jobPlace} ya.|Todos los turnos son obligatorios.]",
    ["[i love you|be careful]. come home now"] = "[te amo|ten cuidado]. ven a casa ya",
    ["[Roads are blocked.|Army has the roads.] Don't try to drive out"] =
        "[Las carreteras están bloqueadas.|El Ejército controla las carreteras.] No intentes salir en auto",
    ["[going to my uncles|heading to the farm]. [u should come|room for u]"] =
        "[me voy con mi tío|vamos a la granja]. [deberías venir|hay lugar para ti]",
    ["[power keeps flickering|lights keep going out]. [battery at 20|need to charge]"] =
        "[la luz sigue parpadeando|se sigue yendo la luz]. [batería al 20|necesito cargar]",
    ["[mom wont answer|cant reach dad]. have u heard from them"] = "[mamá no contesta|no puedo hablar con papá]. sabes algo de ellos",

    -- Their last day
    ["[got bit|it bit me] its not bad"] = "[me mordieron|me mordió] no es grave",
    ["going to [the gas station|the store] for [supplies|water]. back soon"] =
        "voy a [la gasolinera|la tienda] por [provisiones|agua]. ya vuelvo",
    ["where are you"] = "dónde estás",
    ["[answer ur phone|pick up]"] = "[contesta el teléfono|contesta]",
    ["[theres one in the yard|something in the yard]. [staying quiet|lights off]"] =
        "[hay uno en el patio|hay algo en el patio]. [no hago ruido|luces apagadas]",
    ["[Are you eating?|Do you have water?] Call me"] = "[¿Estás comiendo?|¿Tienes agua?] Llámame",
    ["[fever|so cold]. [going to lie down|just need sleep]"] = "[fiebre|mucho frío]. [me voy a acostar|solo necesito dormir]",
    ["[where r u|whats happening there]"] = "[dnd estás|q pasa allá]",

    -- After they died
    ["Please call me back"] = "Por favor llámame",
    ["[{first} please|Baby please answer]"] = "[{first}, por favor|Bebé, por favor contesta]",
    ["Your father drove by your place. Your car's still there. Call us"] =
        "Tu papá pasó por tu casa. Tu auto sigue ahí. Llámanos",
    ["[are you ok|please be ok]"] = "[estás bien|por favor q estés bien]",
    ["[forget the fight|i'm not mad anymore]. just come home"] = "[olvida la pelea|ya se me pasó el enojo]. solo vuelve a casa",
    ["[{first}??|hello?]"] = "[{first}??|hola?]",
    ["[went by ur place|knocked on ur door]. nobody home?"] = "[pasé por tu casa|toqué tu puerta]. no hay nadie?",
    ["[Call your mother.|Your mother is worried sick.]"] = "[Llama a tu mamá.|Tu mamá está con el alma en un hilo.]",
    ["Radio says stay off the roads. Stay where you are."] =
        "La radio dice que no salgas a la carretera. Quédate donde estás.",
    ["[please answer|pick up pick up pick up]"] = "[por favor contesta|contesta contesta contesta]",
    ["mom wont stop crying. just call"] = "mamá no para de llorar. solo llama",
    ["[i'm at home waiting|i left the door unlocked for you]"] = "[estoy en casa esperando|te dejé la puerta abierta]",
    ["[we're leaving tomorrow|leaving at dawn]. [hope ur ok|find us]"] =
        "[nos vamos mañana|salimos al amanecer]. [ojalá estés bien|búscanos]",
    ["[I keep calling.|Your phone just rings.] Please."] = "[Te sigo llamando.|Tu teléfono solo suena.] Por favor.",
    ["{first}, you missed your shift. We need everyone. Call in."] =
        "{first}, faltaste a tu turno. Necesitamos a todos. Repórtate.",

    -- Unsent drafts (used as written)
    ["im at the gas sta"] = "estoy en la gasoli",
    ["tell mom i"] = "dile a mamá q",
    ["dont come h"] = "no vengas a c",
    ["if u find this"] = "si encuentras est",
    ["im sorry for"] = "perdón por",
    ["the kids are w"] = "los niños están c",
    ["dont open the"] = "no abras la",
    ["love yo"] = "te qui",

    -- Notes (the hint words: llave, cabaña, casa del lago, agua en)
    ["milk, eggs, [AMMO??|bullets], insulin for dad"] = "leche, huevos, [MUNICIÓN??|balas], insulina para papá",
    ["[spare key under the mat|key is under the flowerpot]"] =
        "[la llave de repuesto bajo el tapete|la llave está bajo la maceta]",
    ["[supplies at the cabin|we keep water at the lake house] near {hometown}"] =
        "[provisiones en la cabaña|tenemos agua en la casa del lago] cerca de {hometown}",
    ["[Garage code|Safe combo]: [1987|4412|0629]"] = "[Código del garaje|Combinación de la caja fuerte]: [1987|4412|0629]",
    ["Day [2|3]. [Power still on.|No TV now.] Waiting for {partner}."] =
        "Día [2|3]. [Todavía hay luz.|Ya no hay tele.] Esperando a {partner}.",
    ["Call {mom} back. [Tell her we're ok.|Don't scare her.]"] =
        "Llamar a {mom}. [Decirle que estamos bien.|No asustarla.]",
    ["[Boil it first.|Bleach: 8 drops a gallon.]"] = "[Hervirla primero.|Cloro: 8 gotas por galón.]",
    ["[Shells in the truck.|Flashlight in the glovebox.]"] = "[Cartuchos en la camioneta.|Linterna en la guantera.]",
    ["Shifts: [Mon Wed Fri|Tue Thu Sat] at {jobPlace}"] = "Turnos: [lun mié vie|mar jue sáb] en {jobPlace}",

    -- Voicemails on dead phones
    ["Hey, it's me. Call me back when you get this, okay?"] = "Hola, soy yo. Llámame cuando oigas esto, ¿sí?",
    ["This is {work}. We need you at {jobPlace} as soon as you can."] =
        "Habla {work}. Te necesitamos en {jobPlace} lo antes posible.",
    ["[Dude|Hey], where are you? Call me."] = "[Amigo|Oye], ¿dónde estás? Llámame.",
    ["{first}, please call me. I don't know what's happening."] = "{first}, por favor llámame. No sé qué está pasando.",
    ["It's Dad. [Call your mother.|We're okay.] Stay where you are."] =
        "Habla papá. [Llama a tu mamá.|Estamos bien.] Quédate donde estás.",
    ["Hey, it's me. [I'm on my way.|I'm stuck at work.] I love you."] =
        "Hola, soy yo. [Voy para allá.|No puedo salir del trabajo.] Te amo.",
    ["[Where are you?|Are you okay?] Mom's freaking out. Call us."] =
        "[¿Dónde estás?|¿Estás bien?] Mamá está histérica. Llámanos.",

    -- Work group chats
    ["[anyone else seeing this|is anyone ok]?"] = "[alguien más está viendo esto|alguien está bien]?",
    ["[stay home|lock your doors] everyone"] = "[quédense en casa|cierren con llave] todos",
    ["[{jobPlace} is a mess|we're overwhelmed here]"] = "[{jobPlace} es un caos|aquí no damos abasto]",
    ["[roll call|everyone check in] please"] = "[pasen lista|repórtense todos] por favor",
    ["[my power's out|no water pressure here]. anyone else?"] = "[se me fue la luz|aquí no hay presión de agua]. alguien más?",
    ["[heading out at dawn|we're leaving]. [who's coming|meet at the church]"] =
        "[salimos al amanecer|nos vamos]. [quién viene|nos vemos en la iglesia]",

    -- Your family's texts ---------------------------------------------------------------------------------------
    ["We're all at {place}. [Doors locked, curtains shut|Plenty of canned food]. Come if you can"] =
        "Estamos todos en {place}. [Puertas con llave, cortinas cerradas|Tenemos muchas latas]. Ven si puedes",
    ["[Staying put|Sitting tight] at {place} till this blows over. [Come find us|Come when it's safe]"] =
        "[Nos quedamos|Seguimos aguantando] en {place} hasta que esto pase. [Ven a buscarnos|Ven cuando sea seguro]",
    ["They opened {place} as a shelter. We're there. [Come if you can|Bring blankets]"] =
        "Abrieron {place} como refugio. Estamos ahí. [Ven si puedes|Trae cobijas]",
    ["We're at {place} with half the town. [They have cots and water|They're letting everyone in]"] =
        "Estamos en {place} con medio pueblo. [Hay catres y agua|Están dejando entrar a todos]",
    ["Are you safe? [They're saying stay inside|Call me when you can]"] =
        "¿Estás a salvo? [Dicen que nos quedemos adentro|Llámame cuando puedas]",
    ["[Hey|Hey you], the news is scary. Where are you?"] = "[Oye|Hola tú], las noticias dan miedo. ¿Dónde estás?",
    ["We're [okay|fine] here. [Lock the doors|Stay put]"] = "Aquí estamos [bien|tranquilos]. [Cierra con llave|No te muevas]",
    ["[Do you have food?|Did you get groceries?] [We have extra|Come get some]"] =
        "[¿Tienes comida?|¿Compraste víveres?] [Tenemos de sobra|Ven por algo]",
    ["{other} is [boarding up the windows|filling the bathtub]. Call us"] =
        "{other} está [tapando las ventanas|llenando la tina]. Llámanos",
    ["We're [boarding up the windows|filling the bathtub]. Call us"] = "Estamos [tapando las ventanas|llenando la tina]. Llámanos",
    ["{other} is [helping with the cots|handing out water]. Call us"] =
        "{other} está [ayudando con los catres|repartiendo agua]. Llámanos",
    ["We're [helping with the cots|handing out water]. Call us"] = "Estamos [ayudando con los catres|repartiendo agua]. Llámanos",
    ["[The phone lines are so bad.|Can't get through on the house phone.] Text back"] =
        "[Las líneas están fatal.|No entra nada por el teléfono de la casa.] Contéstame por mensaje",
    ["{other} has a fever. Probably nothing"] = "{other} tiene fiebre. Seguro no es nada",
    ["Grandpa has a fever. Probably nothing"] = "El abuelo tiene fiebre. Seguro no es nada",
    ["I don't feel so good. [Lying down|Gonna rest]"] = "No me siento muy bien. [Me voy a acostar|Voy a descansar]",
    ["[Got scratched|Something grabbed me] at the store. It's fine"] = "[Me rasguñaron|Algo me agarró] en la tienda. No es nada",
    ["[Running a fever.|Up sick all night.] Don't come over"] = "[Tengo fiebre.|Pasé toda la noche mal.] No vengas",
    ["{other} got bit by the neighbor. [It looks bad|They say it's fine]"] =
        "El vecino mordió a {other}. [Se ve mal|Dicen que no es nada]",
    ["The neighbor's boy got bit. [It looks bad|They say it's fine]"] =
        "Mordieron al hijo del vecino. [Se ve mal|Dicen que no es nada]",
    ["[It's getting worse.|I can't get up.] I love you"] = "[Está empeorando.|No me puedo levantar.] Te quiero",
    ["{other} didn't make it. Please come home"] = "{other} no lo logró. Por favor ven a casa",
    ["Grandma didn't make it. Please come home"] = "La abuela no lo logró. Por favor ven a casa",
    ["[If you get this|When you get this], we're at {place}"] = "[Si te llega esto|Cuando te llegue esto], estamos en {place}",
    ["[Can't stop shaking.|Everything hurts.] [Don't come|Stay away from here]"] =
        "[No paro de temblar.|Me duele todo.] [No vengas|Aléjate de aquí]",
    ["{other} isn't right anymore. [I locked the door|I'm scared]"] =
        "{other} ya no está bien. [Cerré la puerta con llave|Tengo miedo]",
    ["The neighbor isn't right anymore. [I locked the door|I'm scared]"] =
        "El vecino ya no está bien. [Cerré la puerta con llave|Tengo miedo]",
    ["[We're leaving town.|Heading north.] Don't come here. I love you"] =
        "[Nos vamos del pueblo.|Vamos al norte.] No vengas aquí. Te quiero",
    ["[Phone's dying.|Battery's almost gone.] Stay safe. Love you"] =
        "[Se me muere el teléfono.|Casi no tengo batería.] Cuídate. Te quiero",
    ["[The radio says go north.|We're following the convoy.] [Love you always|I'll find you]"] =
        "[La radio dice que vayamos al norte.|Vamos siguiendo al convoy.] [Te quiero siempre|Te voy a encontrar]",
    ["Left you a note at {place}. Don't wait for us"] = "Te dejé una nota en {place}. No nos esperes",
    ["We made it to the camp by the fence. Safe for now"] = "Llegamos al campamento junto a la cerca. A salvo por ahora",
    ["[The army took us to the camp by the fence.|We're at the camp by the fence.] Come find us there"] =
        "[El ejército nos llevó al campamento junto a la cerca.|Estamos en el campamento junto a la cerca.] Búscanos ahí",
    ["[A truck came for us at {place}.|Soldiers came by {place}.] They're taking us to the camp by the fence"] =
        "[Un camión vino por nosotros a {place}.|Unos soldados pasaron por {place}.] Nos llevan al campamento junto a la cerca",
    ["[They say buses are coming for us.|Soldiers say we'll be out soon.] [Will call when I can|Stay put]"] =
        "[Dicen que vienen autobuses por nosotros.|Los soldados dicen que pronto salimos.] [Te llamo cuando pueda|No te muevas]",
    ["please dont come here"] = "por favor no vengas aqui",
    ["im so sorry baby"] = "perdóname bebé",
    ["i love you so mu"] = "te quiero muchísi",
    ["the door is lock"] = "la puerta tiene ll",
    ["if you find this"] = "si encuentras esto",

    -- Strangers texting about real places ----------------------------------------------------------------------
    ["Holed up at {place}. [We have food.|Plenty of water.] [Knock three times.|Come at noon.]"] =
        "Atrincherados en {place}. [Tenemos comida.|Hay mucha agua.] [Toquen tres veces.|Vengan al mediodía.]",
    ["[If anyone gets this|To anyone out there]: {place} is safe. [Bring meds.|We trade.]"] =
        "[Si alguien recibe esto|Para quien esté ahí afuera]: {place} es un lugar seguro. [Traigan medicinas.|Hacemos trueque.]",
    ["[Anyone on this network?|Is anybody out there?|This is {sender}.] [We're at {place}.|Holed up at {place}.] [Bring batteries.|Trade for fuel.]"] =
        "[¿Alguien en esta red?|¿Hay alguien ahí?|Habla {sender}.] [Estamos en {place}.|Atrincherados en {place}.] [Traigan pilas.|Cambiamos por combustible.]",
    ["[Signal fire tonight at {place}.|Lights on at {place} after dark.] [Come if you can.|We'll wait.]"] =
        "[Fogata de señal esta noche en {place}.|Luces encendidas en {place} al anochecer.] [Vengan si pueden.|Los esperamos.]",
    ["[On the roof of|Upstairs at] {place}. [We're friendly. Don't shoot.|Stairs are blocked. Bring a ladder.]"] =
        "[En el techo de|Arriba en] {place}. [Somos amigables. No disparen.|La escalera está bloqueada. Traigan una escalera de mano.]",
    ["[Six of us at {place}.|Three of us at {place}.] [Looking for a doctor.|Need antibiotics.]"] =
        "[Somos seis en {place}.|Somos tres en {place}.] [Buscamos un médico.|Necesitamos antibióticos.]",
    ["It's {sender}. [Mom and me|Me and my brother] are at {place}. No food for two days."] =
        "Habla {sender}. [Mi mamá y yo|Mi hermano y yo] estamos en {place}. Dos días sin comida.",
    ["[Need insulin.|Need baby formula.] Will trade. Back door of {place}."] =
        "[Necesito insulina.|Necesito fórmula para bebé.] Hago trueque. Puerta de atrás de {place}.",
    ["[Radio says|Heard on the radio] {place} still has power. [Anyone know?|Is it true?]"] =
        "[La radio dice|Oí en la radio] que {place} todavía tiene luz. [¿Alguien sabe?|¿Es cierto?]",
    ["[Don't go to|AVOID] {place}. [Too many of them.|It's overrun.]"] = "[No vayan a|EVITEN] {place}. [Hay demasiados.|Está infestado.]",
    ["[Do NOT trust the people at|Stay away from the guys at] {place}. [They shoot first.|They took our stuff.]"] =
        "[NO confíen en la gente de|Aléjense de los tipos de] {place}. [Disparan primero.|Nos quitaron nuestras cosas.]",
    ["Heard shooting at {place} last night. [Stay away.|Don't go there.] - {sender}"] =
        "Se oyeron disparos en {place} anoche. [Aléjense.|No vayan ahí.] - {sender}",

    -- Survivor stashes (Story/Sites quests)
    ["It's {sender}. We got into the back of {place} before they did. Left a bag of meds behind the counter. Can't go back for it."] =
        "Habla {sender}. Entramos a la parte de atrás de {place} antes que ellos. Dejamos una bolsa de medicinas detrás del mostrador. No podemos volver por ella.",
    ["[My husband|My brother] died at {place} getting [insulin|antibiotics] for me. The bag's still by the counter. Please use it."] =
        "[Mi esposo|Mi hermano] murió en {place} consiguiéndome [insulina|antibióticos]. La bolsa sigue junto al mostrador. Por favor úsenla.",
    ["We hid what we found in the back room at {place}. [Two of them got in after us.|The front door won't lock.] Be careful."] =
        "Escondimos lo que encontramos en el cuarto de atrás de {place}. [Dos de ellos entraron después de nosotros.|La puerta de enfrente no cierra.] Tengan cuidado.",
    ["Left canned food and batteries in a bag at {place}. Truck's dead, we're on foot now. Take it. - {sender}"] =
        "Dejamos latas y pilas en una bolsa en {place}. La camioneta murió, ahora vamos a pie. Llévensela. - {sender}",
    ["Holed up at {place} three days. [Gone now.|Moving on.] There's a bag of food in the back if you need it."] =
        "Estuvimos tres días atrincherados en {place}. [Ya nos fuimos.|Seguimos adelante.] Hay una bolsa de comida atrás si la necesitan.",
    ["[Don't let it go to waste.|Somebody should have it.] Food in a duffel in the back office at {place}. We couldn't carry it all."] =
        "[Que no se desperdicie.|Alguien debería aprovecharla.] Hay comida en una maleta en la oficina de atrás de {place}. No pudimos cargar todo.",
    ["It's {sender}. [We lost the station.|The station's gone.] Ammo in a bag in the locker room at {place}. Don't let it rot there."] =
        "Habla {sender}. [Perdimos la estación.|La estación ya no existe.] Hay munición en una bolsa en los vestidores de {place}. Que no se pudra ahí.",
    ["There's a police bag with shells in it at {place}. [Last locker on the left.|By the cells.] We're not going back."] =
        "Hay una bolsa de la policía con cartuchos en {place}. [El último casillero a la izquierda.|Junto a las celdas.] No vamos a volver.",
    ["Grabbed what we could from {place}. Left a bag inside, too heavy. [Go in quiet.|They come when you make noise.]"] =
        "Sacamos lo que pudimos de {place}. Dejamos una bolsa adentro, pesaba mucho. [Entren en silencio.|Vienen cuando haces ruido.]",

    -- Places strangers name (Story/Places) ---------------------------------------------------------------------
    ["the Muldraugh motel"] = "el motel de Muldraugh",
    ["Spiffo's in Muldraugh"] = "Spiffo's de Muldraugh",
    ["the lumberyard in Muldraugh"] = "el aserradero de Muldraugh",
    ["the school in Muldraugh"] = "la escuela de Muldraugh",
    ["Twiggy's Bar in West Point"] = "el bar Twiggy's de West Point",
    ["the West Point town hall"] = "la alcaldía de West Point",
    ["the Rosewood courthouse"] = "el juzgado de Rosewood",
    ["the Rosewood fire station"] = "la estación de bomberos de Rosewood",
    ["the Rosewood police station"] = "la estación de policía de Rosewood",
    ["the prison in Rosewood"] = "la prisión de Rosewood",
    ["the West Maple Country Club"] = "el West Maple Country Club",
    ["the Star-E-Plex in March Ridge"] = "el Star-E-Plex de March Ridge",
    ["the old bunker at March Ridge"] = "el viejo búnker de March Ridge",
    ["the Irvington Speedway"] = "el autódromo de Irvington",
    ["the gun store in Irvington"] = "la armería de Irvington",
    ["the Brott cattle farm"] = "el rancho ganadero Brott",
    ["the Pondview Shopping Center in Brandenburg"] = "el centro comercial Pondview de Brandenburg",
    ["the steelworks in Ekron"] = "la acería de Ekron",
    ["Crossroads Mall in Valley Station"] = "el centro comercial Crossroads de Valley Station",

    -- Jobs (Story/Jobs): what they do (the journal), where they work ({jobPlace}), who texts from work, the work chat
    ["police officer"] = "Policía", ["nurse"] = "Enfermería", ["doctor"] = "Medicina", ["paramedic"] = "Ambulancias",
    ["firefighter"] = "Bomberos", ["construction worker"] = "Construcción", ["mechanic"] = "Mecánica", ["cook"] = "Cocina",
    ["waiter"] = "Meseros", ["cashier"] = "Cajas", ["teacher"] = "Docencia", ["office worker"] = "Oficina",
    ["farmer"] = "Campo", ["mail carrier"] = "Correo", ["security guard"] = "Seguridad", ["soldier"] = "Ejército",
    ["between jobs"] = "Sin trabajo",
    ["the station"] = "la estación", ["the hospital"] = "el hospital", ["the ambulance bay"] = "la base de ambulancias",
    ["the firehouse"] = "la estación de bomberos", ["the site"] = "la obra", ["the shop"] = "el taller",
    ["the diner"] = "la cafetería", ["the store"] = "la tienda", ["summer school"] = "la escuela de verano",
    ["the office"] = "la oficina", ["the farm"] = "la granja", ["the post office"] = "la oficina de correos",
    ["the plant"] = "la planta", ["the base"] = "la base", ["home"] = "casa",
    ["Sgt. {surnameA}"] = "Sgto. {surnameA}", ["Charge Nurse {firstA}"] = "Jefe de enfermería {firstA}",
    ["Dr. {surnameA}"] = "Dr. {surnameA}", ["{firstA} (EMS partner)"] = "{firstA} (ambulancia)",
    ["Capt. {surnameA}"] = "Cap. {surnameA}", ["{firstA} (foreman)"] = "{firstA} (capataz)", ["{firstA} (shop)"] = "{firstA} (taller)",
    ["{firstA} (manager)"] = "{firstA} (gerente)", ["{firstA} (shift lead)"] = "{firstA} (trabajo)",
    ["Principal {surnameA}"] = "Dir. {surnameA}", ["{firstA} (boss)"] = "{firstA} (jefe)", ["{firstA} (route lead)"] = "{firstA} (ruta)",
    ["{firstA} (night shift)"] = "{firstA} (turno noche)",
    ["Dispatch"] = "Despacho", ["3rd Floor Nurses"] = "Enfermeras 3er piso", ["ER Attendings"] = "Urgencias",
    ["EMS Crew"] = "Equipo de ambulancia", ["Station 2"] = "Estación 2", ["Site Crew"] = "Cuadrilla de obra", ["Staff"] = "Personal",
    ["Team"] = "Equipo", ["Squad"] = "Escuadra",

    -- The family on your phone (Story/Names); texts always call parents Mamá and Papá
    ["Mom"] = "Mamá", ["Mama"] = "Ma", ["Mother"] = "Madre", ["Mommy"] = "Mami",
    ["Dad"] = "Papá", ["Daddy"] = "Papi", ["Pop"] = "Pa", ["Pops"] = "Viejo",
    ["Work"] = "Trabajo",

    -- Lines the code writes itself: the journal, found phones' notes, calls ------------------------------------
    ["Journal"] = "Diario",
    ["{month} {day}"] = "{day} {month}",
    ["Day {n}"] = "Día {n}",
    ["Jul"] = "jul", ["Aug"] = "ago", ["Sep"] = "sep", ["Oct"] = "oct", ["Nov"] = "nov", ["Dec"] = "dic",
    ["Turned on {who}'s phone."] = "Encendí el teléfono de {who}.",
    ["Never sent: \"{text}\""] = "Nunca enviado: \"{text}\"",
    ["Last thing they wrote: \"{text}\""] = "Lo último que escribió: \"{text}\"",
    ["{who} told me about a bag at {place}."] = "{who} me contó de una bolsa en {place}.",
    ["{who} knows about {owner} now. I told them."] = "{who} ya sabe lo de {owner}. Se lo dije.",
    ["Home was {home}."] = "Su casa era {home}.",
    ["{owner}'s crew know somebody has the phone."] = "El grupo de {owner} sabe que alguien tiene el teléfono.",
    ["Took {who}'s phone home to {home}."] = "Llevé el teléfono de {who} de vuelta a {home}.",
    ["That's {count} I've brought home."] = "Ya van {count} que llevo a casa.",
    ["Heard on {owner}'s phone: {faction} are going for a place near {town} tonight."] =
        "Oí en el teléfono de {owner}: {faction} va por un lugar cerca de {town} esta noche.",
    ["Got tower {code} back on the air."] = "Puse la antena {code} en servicio otra vez.",
    ["Got my phone back from {who}."] = "Recuperé mi teléfono de {who}.",
    ["{who} took one of my phones."] = "{who} se llevó uno de mis teléfonos.",
    ["411 gave me: {list}."] = "El 411 me dio: {list}.",
    ["them"] = "ellos", ["Somebody"] = "Alguien", ["town"] = "el pueblo",
    ["the house in {town}"] = "la casa en {town}",
    ["call %s %s"] = "llamar %s %s",
    ["%s - %s (ask for Dee)"] = "%s - %s (preguntar por Dee)",
    ["%s %s after 5"] = "%s %s después de las 5",
    ["refill: %s %s"] = "resurtir: %s %s",
    ["honey"] = "cariño",
    ["The crew"] = "El grupo",
}

-- The buildings the family holes up in and the stashes (Story/Sites): "the house on Lime St in Muldraugh" is "la casa
-- de Lime St en Muldraugh". Made from the list, so a building added there reads in Spanish too.
local Sites = require "KnoxMobile/Story/Sites"
local KIND = { house = "la casa", church = "la iglesia", school = "la escuela", pharmacy = "la farmacia",
    gas = "la gasolinera", police = "la estación de policía" }
for _, list in ipairs({ Sites.family, Sites.quests }) do
    for _, s in ipairs(list) do
        local street, town = tostring(s.name):match("^the .- on (.+) in (.+)$")
        if street and KIND[s.kind] and D[s.name] == nil then D[s.name] = KIND[s.kind] .. " de " .. street .. " en " .. town end
    end
end

return D
