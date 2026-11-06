-- Spanish for what people say on the phones (Core/Lang, 0.2.5): voicemails and texts put together from parts
-- (Core/Voicemail, Core/Texts), your family's calls and answers (Core/FamilyCall, Core/FamilyText), texting back
-- (Core/Replies), strangers (Core/Strangers), an A-Life crew (Core/FactionChatter, Data/WireLines), recordings
-- (Core/Recordings) and PIN notes (Core/Clues). Neutral Latin American Spanish, "tú"; the English line is the key.
-- Lines that may come from a mother or a father, about a player who may be a man or a woman, are written so that
-- they fit anyone ("me preocupas", not "estoy preocupada").
return {
    -- Voicemail greetings (Core/Voicemail.GREET) ---------------------------------------------------------------
    ["Hi {name}, it's Mom."] = "Hola {name}, habla mamá.",
    ["Honey, it's me."] = "Cariño, soy yo.",
    ["{name}, it's your mother."] = "{name}, habla tu madre.",
    ["It's Mom. Pick up if you're there."] = "Habla mamá. Contesta si estás ahí.",
    ["Hi sweetheart, it's me."] = "Hola corazón, soy yo.",
    ["{name}? It's Mom. Are you there?"] = "¿{name}? Habla mamá. ¿Estás ahí?",
    ["{name}, it's Dad."] = "{name}, habla papá.",
    ["It's your father."] = "Habla tu padre.",
    ["Hey, it's Dad. Pick up."] = "Oye, habla papá. Contesta.",
    ["This is Dad."] = "Soy papá.",
    ["{name}. Dad."] = "{name}. Papá.",
    ["{name}, this is Grandma. I hope I'm doing this right."] = "{name}, habla la abuela. Espero estar haciendo esto bien.",
    ["It's Grandma, honey."] = "Habla la abuela, cariño.",
    ["Hello? {name}? It's your grandmother."] = "¿Hola? ¿{name}? Habla tu abuela.",
    ["Hi baby, it's Grandma."] = "Hola mi cielo, habla la abuela.",
    ["hey, it's me."] = "oye, soy yo.",
    ["{name}. it's me. pick up."] = "{name}. soy yo. contesta.",
    ["it's me again."] = "soy yo otra vez.",
    ["hey. it's your favorite sibling."] = "oye. adivina quién.",
    ["It's me."] = "Soy yo.",
    ["Hey. It's me."] = "Hola. Soy yo.",
    ["Baby, it's me."] = "Amor, soy yo.",
    ["{name}, it's me. Please pick up."] = "{name}, soy yo. Por favor contesta.",
    ["Hi. It's me again."] = "Hola. Soy yo otra vez.",
    ["Hey {name}, it's {caller}."] = "Hola {name}, habla {caller}.",
    ["{name}! It's {caller}."] = "¡{name}! Habla {caller}.",
    ["It's {caller}. You there?"] = "Habla {caller}. ¿Estás ahí?",
    ["Yo, it's {caller}."] = "Qué tal, habla {caller}.",
    ["Hey, it's {caller}. Pick up, pick up."] = "Hola, habla {caller}. Contesta, contesta.",
    ["{name}, this is {caller} at work."] = "{name}, habla {caller} del trabajo.",
    ["Message for {name}. This is {caller}."] = "Mensaje para {name}. Habla {caller}.",
    ["Hi, it's {caller} from work."] = "Hola, habla {caller}, del trabajo.",
    ["{name}, {caller} here."] = "{name}, aquí {caller}.",
    ["Hi {name}, it's {caller} from next door."] = "Hola {name}, habla {caller}, de al lado.",
    ["{name}, it's {caller}, your neighbor."] = "{name}, habla {caller}, de la casa de al lado.",
    ["Hey there, it's {caller} across the street."] = "Hola, habla {caller}, de enfrente.",

    -- What happened (Core/Voicemail.BODY)
    ["The [heat|humidity] is something today. I hope you're keeping cool."] =
        "[El calor|La humedad] está terrible hoy. Espero que te estés refrescando.",
    ["Your [cousin|aunt] called asking about the Fourth. I said we'd do the usual."] =
        "Llamó tu [primo|tía] preguntando por el 4 de julio. Le dije que haríamos lo de siempre.",
    ["I found that [casserole dish|cooler] you were looking for. It was in the garage the whole time."] =
        "Encontré [la fuente de horno|la hielera] que buscabas. Estuvo en el garaje todo el tiempo.",
    ["The [car|truck] is making that noise again. I'm not touching it till Sunday."] =
        "[El auto|La camioneta] está haciendo ese ruido otra vez. No le meto mano hasta el domingo.",
    ["We're doing burgers Sunday after church. Nothing fancy."] =
        "Vamos a hacer hamburguesas el domingo después de la iglesia. Nada elegante.",
    ["I saw your old teacher at the IGA. She asked about you. I said you're doing real good."] =
        "Vi a tu antigua maestra en el IGA. Preguntó por ti. Le dije que te va muy bien.",
    ["The tomatoes are coming in. I've got more than I know what to do with."] =
        "Ya están saliendo los tomates. Tengo más de los que sé qué hacer con ellos.",
    ["I paid the phone bill so don't worry about it this month."] = "Pagué la cuenta del teléfono, así que no te preocupes este mes.",
    ["The [dog|cat] got into the trash again. Just so you know."] = "[El perro|El gato] se metió a la basura otra vez. Solo para que sepas.",
    ["We're thinking about the lake next weekend if the weather holds."] =
        "Estamos pensando en ir al lago el próximo fin de semana si el clima aguanta.",
    ["Somebody said the plant's hiring for second shift. Thought of you."] =
        "Alguien dijo que en la planta están contratando para el segundo turno. Pensé en ti.",
    ["I'm making a run to {town} tomorrow if you need anything."] = "Mañana voy a {town} por si necesitas algo.",
    ["The church needs help setting up for the supper Wednesday."] = "La iglesia necesita ayuda para preparar la cena del miércoles.",
    ["Your [brother|sister] says hi. Well, sort of. They grunted."] =
        "Tu [hermano|hermana] te manda saludos. Bueno, más o menos. Gruñó.",
    ["There's a sale on fans at the hardware. Might be worth it, this heat."] =
        "Hay oferta de ventiladores en la ferretería. Puede que valga la pena, con este calor.",
    ["I heard there's a flu going around Louisville. Wash your hands."] = "Oí que anda una gripe en Louisville. Lávate las manos.",
    ["The fireworks are at the river this year. We'll save you a spot."] =
        "Los fuegos artificiales son en el río este año. Te apartamos un lugar.",
    ["I left your mail on the kitchen table."] = "Te dejé tu correo en la mesa de la cocina.",
    ["Are you watching the news? I don't know what to make of it."] = "¿Estás viendo las noticias? No sé qué pensar.",
    ["They're saying the hospitals in Louisville are full. Full! Can you believe it?"] =
        "Dicen que los hospitales de Louisville están llenos. ¡Llenos! ¿Puedes creerlo?",
    ["The IGA was out of [bottled water|bread] when I got there. People are buying everything."] =
        "En el IGA ya no había [agua embotellada|pan] cuando llegué. La gente está comprando todo.",
    ["They cancelled the fireworks. Some people already left the river."] =
        "Cancelaron los fuegos artificiales. Algunos ya se fueron del río.",
    ["The church opened its doors tonight for anybody who needs a place."] =
        "La iglesia abrió sus puertas esta noche para quien necesite un lugar.",
    ["There were sirens going all night. I didn't sleep a wink."] = "Hubo sirenas toda la noche. No pegué el ojo.",
    ["Your father filled the tub and every pot we have, just in case."] =
        "Tu papá llenó la tina y todas las ollas que tenemos, por si acaso.",
    ["Somebody on the radio said stay inside tonight. So we're staying inside."] =
        "Alguien en la radio dijo que nos quedemos adentro esta noche. Así que nos quedamos adentro.",
    ["I keep getting a busy signal. I don't know if this'll even go through."] =
        "Me sigue saliendo ocupado. No sé si esto va a llegar siquiera.",
    ["The man down the road said there was trouble at the gas station. Somebody got hurt."] =
        "El señor de más abajo dijo que hubo problemas en la gasolinera. Alguien salió herido.",
    ["We saw Army trucks on the highway. A lot of them."] = "Vimos camiones del Ejército en la carretera. Muchos.",
    ["The TV keeps saying don't panic. That's what's making me panic."] =
        "La tele sigue diciendo que no entremos en pánico. Eso es lo que me da pánico.",
    ["Everybody's talking about the flu but nobody's saying what it really is."] =
        "Todos hablan de la gripe pero nadie dice qué es en realidad.",
    ["We're all right here. I just want to hear your voice."] = "Aquí estamos bien. Solo quiero oír tu voz.",
    ["They closed the roads this morning. Soldiers at the bridge, turning everybody around."] =
        "Cerraron las carreteras esta mañana. Hay soldados en el puente, regresando a todos.",
    ["The phone's been acting funny all day. If this cuts off, I love you."] =
        "El teléfono ha estado raro todo el día. Si esto se corta, te quiero.",
    ["Nobody's going anywhere. They put a fence up out by the highway."] =
        "Nadie va a ningún lado. Pusieron una cerca junto a la carretera.",
    ["We're staying at the church. There's room if you need it."] = "Nos estamos quedando en la iglesia. Hay lugar si lo necesitas.",
    ["The power keeps flickering. We've got the lamps out."] = "La luz sigue parpadeando. Sacamos las lámparas.",
    ["There's a curfew now. After dark nobody's supposed to be out."] =
        "Ahora hay toque de queda. Después del anochecer nadie debe estar afuera.",
    ["The neighbors left last night. Just packed the car and went."] = "Los vecinos se fueron anoche. Cargaron el auto y se fueron.",
    ["I heard shooting by the school last night. It's probably nothing."] = "Oí disparos por la escuela anoche. Seguro no es nada.",
    ["We're running low on [milk|bread] but we'll make do."] = "Se nos está acabando [la leche|el pan] pero nos las arreglamos.",
    ["Some people are saying the Army will bring supplies. I'll believe it when I see it."] =
        "Algunos dicen que el Ejército va a traer provisiones. Lo creeré cuando lo vea.",
    ["I put your name on the list at the church so they know you're with us."] =
        "Puse tu nombre en la lista de la iglesia para que sepan que estás con nosotros.",
    ["If you can't get here, stay where you are. Lock the doors."] =
        "Si no puedes llegar, quédate donde estás. Cierra las puertas con llave.",
    ["I've been calling all day."] = "Te he llamado todo el día.",
    ["I don't know if you're getting these."] = "No sé si te están llegando.",
    ["Your [car|truck] is still in the drive. I don't understand."] = "[Tu auto|Tu camioneta] sigue en la entrada. No entiendo.",
    ["Somebody said they saw you at the [gas station|IGA]. Was it you?"] =
        "Alguien dijo que te vio en [la gasolinera|el IGA]. ¿Eras tú?",
    ["I went by your place. The door was open. I didn't go in."] = "Pasé por tu casa. La puerta estaba abierta. No entré.",
    ["I kept your dinner in the oven. I'll keep it there."] = "Te guardé la cena en el horno. Ahí la voy a dejar.",
    ["The phone just rings and rings."] = "El teléfono solo suena y suena.",
    ["Your [mother|father] is worried sick. So am I."] = "[Tu mamá|Tu papá] no deja de preocuparse. Yo tampoco.",
    ["We're at the church now. They have a list. Your name's not on it yet."] =
        "Ahora estamos en la iglesia. Tienen una lista. Tu nombre todavía no está.",
    ["I fed your [dog|cat]. Don't worry about that."] = "Le di de comer a tu [perro|gato]. No te preocupes por eso.",
    ["It's getting dark again."] = "Ya está oscureciendo otra vez.",
    ["I'm not mad. Whatever it is, I'm not mad."] = "No me enojo. Sea lo que sea, no me enojo.",
    ["(a long pause) I'm still here."] = "(una pausa larga) Sigo aquí.",
    ["The power went out an hour ago. I'm calling while I can."] = "Se fue la luz hace una hora. Te llamo mientras puedo.",
    ["I keep thinking you'll just walk in."] = "Sigo pensando que vas a entrar por la puerta.",
    ["They say not to go out after dark, so I'm going to wait for you here."] =
        "Dicen que no salgamos de noche, así que te voy a esperar aquí.",

    -- A boss or coworker (Core/Voicemail.WORK)
    ["We need someone to cover [Saturday|Sunday]. Time and a half."] =
        "Necesitamos a alguien que cubra el [sábado|domingo]. Pagamos tiempo y medio.",
    ["The schedule for next week is posted. You're on [mornings|nights]."] =
        "Ya está el horario de la próxima semana. Te toca [en las mañanas|en las noches].",
    ["Your check is in the office if you want it before the weekend."] =
        "Tu cheque está en la oficina si lo quieres antes del fin de semana.",
    ["The truck's coming early tomorrow. We need you at six."] = "El camión llega temprano mañana. Te necesitamos a las seis.",
    ["Somebody called in sick again. Can you come in tonight?"] = "Alguien se reportó enfermo otra vez. ¿Puedes venir esta noche?",
    ["Don't forget the safety meeting [Monday|Wednesday]."] = "No olvides la reunión de seguridad del [lunes|miércoles].",
    ["We're closing early today. Don't come in after three."] = "Hoy cerramos temprano. No vengas después de las tres.",
    ["Corporate says keep the doors open, but I'm not making anybody come in."] =
        "La empresa dice que sigamos abiertos, pero no voy a obligar a nadie a venir.",
    ["Half the crew didn't show up today. If you can come in, come in."] = "Hoy faltó la mitad del personal. Si puedes venir, ven.",
    ["They're saying stay home, so stay home. We'll sort out the hours later."] =
        "Dicen que nos quedemos en casa, así que quédate en casa. Las horas las arreglamos después.",
    ["We're closed until further notice. Don't come in."] = "Cerramos hasta nuevo aviso. No vengas.",
    ["Your last check is in the drop box. I'm sorry it's not more."] = "Tu último cheque está en el buzón. Perdón que no sea más.",
    ["I'm locking up for good. Take care of your family."] = "Cierro para siempre. Cuida a tu familia.",
    ["If anybody asks, the keys are with me."] = "Si alguien pregunta, yo tengo las llaves.",
    ["You missed your shift. That's not like you."] = "Faltaste a tu turno. No es normal en ti.",
    ["Nobody's heard from you. Just let us know you're okay."] = "Nadie sabe nada de ti. Solo avísanos que estás bien.",
    ["We kept your spot. Whenever you can."] = "Te guardamos el puesto. Cuando puedas.",
    ["Your locker's still got your stuff in it."] = "Tus cosas siguen en tu casillero.",

    -- What they ask, how they hang up (Core/Voicemail.ASK, BYE)
    ["Call me back."] = "Llámame.",
    ["Call me when you get this."] = "Llámame cuando oigas esto.",
    ["No need to call back."] = "No hace falta que me llames.",
    ["Let me know."] = "Avísame.",
    ["Call when you can."] = "Llama cuando puedas.",
    ["Call me as soon as you get this."] = "Llámame en cuanto oigas esto.",
    ["Stay inside tonight."] = "Quédate adentro esta noche.",
    ["Call me back, okay?"] = "Llámame, ¿sí?",
    ["Please call."] = "Por favor llama.",
    ["If you get this, call. Please."] = "Si oyes esto, llama. Por favor.",
    ["Don't try the highway."] = "No intentes ir por la carretera.",
    ["Stay where you are."] = "Quédate donde estás.",
    ["Call when you can, if you can."] = "Llama cuando puedas, si puedes.",
    ["Please. Just call."] = "Por favor. Solo llama.",
    ["Just let me know you're okay."] = "Solo dime que estás bien.",
    ["I'll keep trying."] = "Voy a seguir intentando.",
    ["Please call me back."] = "Por favor llámame.",
    ["Just say anything."] = "Solo di algo.",
    ["Love you."] = "Te quiero.",
    ["Okay. Love you, honey. Bye."] = "Bueno. Te quiero, cariño. Adiós.",
    ["Bye-bye."] = "Adiós, adiós.",
    ["I love you. Bye."] = "Te quiero. Adiós.",
    ["Bye."] = "Adiós.",
    ["Okay."] = "Bueno.",
    ["Talk later."] = "Hablamos luego.",
    ["All right. Bye."] = "Muy bien. Adiós.",
    ["Love, Grandma. Oh, you don't say that on these. Bye now."] =
        "Con cariño, la abuela. Ay, eso no se dice en estas cosas. Adiós.",
    ["Bye, honey."] = "Adiós, cariño.",
    ["God bless. Bye."] = "Que Dios te bendiga. Adiós.",
    ["bye."] = "chao.",
    ["later."] = "nos vemos.",
    ["love you, idiot."] = "te quiero, idiota.",
    ["ok bye."] = "ok chao.",
    ["I love you."] = "Te amo.",
    ["Love you. Bye."] = "Te amo. Adiós.",
    ["Okay. I love you."] = "Bueno. Te amo.",
    ["Later."] = "Luego.",
    ["See ya."] = "Nos vemos.",
    ["Talk soon."] = "Hablamos pronto.",
    ["Thanks."] = "Gracias.",
    ["Thanks. Bye."] = "Gracias. Adiós.",
    ["Appreciate it."] = "Te lo agradezco.",
    ["Take care now."] = "Cuídate.",
    ["Bye now."] = "Hasta luego.",
    ["Okay, bye."] = "Bueno, adiós.",

    -- Texts put together from parts (Core/Texts) ---------------------------------------------------------------
    ["It's [97|98|99] on the bank sign"] = "El letrero del banco marca [97|98|99]",
    ["The AC's out again"] = "Se descompuso el aire otra vez",
    ["Mowed the yard. Finally"] = "Corté el pasto. Por fin",
    ["Your [cousin|aunt] is coming for the Fourth"] = "Tu [primo|tía] viene para el 4 de julio",
    ["Got off early today"] = "Hoy salí temprano",
    ["The [truck|car] won't start again"] = "[La camioneta|El auto] no arranca otra vez",
    ["Cookout Sunday after church"] = "Parrillada el domingo después de la iglesia",
    ["Found your [sunglasses|keys] in my car"] = "Encontré tus [lentes de sol|llaves] en mi auto",
    ["Paid the phone bill"] = "Pagué la cuenta del teléfono",
    ["The tomatoes are coming in"] = "Ya están saliendo los tomates",
    ["Heard there's a flu going around Louisville"] = "Oí que anda una gripe en Louisville",
    ["Ran into your old [teacher|coach] at the IGA"] = "Me encontré a tu antiguo [maestro|entrenador] en el IGA",
    ["Gas went up again"] = "Subió la gasolina otra vez",
    ["There's a sale on fans at the hardware"] = "Hay oferta de ventiladores en la ferretería",
    ["The [dog|cat] got out again. Found it"] = "[El perro|El gato] se salió otra vez. Ya lo encontré",
    ["Watching the ballgame"] = "Viendo el partido",
    ["Got the overtime"] = "Me dieron las horas extra",
    ["Fireworks at the river this year"] = "Fuegos artificiales en el río este año",
    ["The power blinked during the storm"] = "Se fue la luz un momento con la tormenta",
    ["Church supper is Wednesday"] = "La cena de la iglesia es el miércoles",
    ["Washed your car. You're welcome"] = "Te lavé el auto. De nada",
    ["Grandma wants us all there Sunday"] = "La abuela nos quiere a todos allá el domingo",
    ["The sitter cancelled"] = "La niñera canceló",
    ["Bought a new [mattress|lawnmower]. Don't ask what it cost"] = "Compré [un colchón nuevo|una podadora nueva]. No preguntes cuánto costó",
    ["Turn on channel 3"] = "Pon el canal 3",
    ["The hospital in Louisville is full"] = "El hospital de Louisville está lleno",
    ["They cancelled the fireworks"] = "Cancelaron los fuegos artificiales",
    ["The IGA is out of [water|bread|batteries]"] = "En el IGA ya no hay [agua|pan|pilas]",
    ["Sirens all night"] = "Sirenas toda la noche",
    ["Church is open for anybody"] = "La iglesia está abierta para todos",
    ["Filled the tub just in case"] = "Llené la tina por si acaso",
    ["Somebody got bit at the gas station"] = "Mordieron a alguien en la gasolinera",
    ["Army trucks on the highway"] = "Camiones del Ejército en la carretera",
    ["Can't get through to anybody. All circuits busy"] = "No puedo comunicarme con nadie. Todos los circuitos ocupados",
    ["The radio says stay inside"] = "La radio dice que no salgamos",
    ["School's a shelter now"] = "La escuela ahora es refugio",
    ["They're saying it's a flu. It's not a flu"] = "Dicen que es una gripe. No es una gripe",
    ["Your [uncle|cousin] in Louisville won't answer"] = "Tu [tío|primo] de Louisville no contesta",
    ["Got the last case of water"] = "Conseguí la última caja de agua",
    ["Lines at every gas station"] = "Filas en todas las gasolineras",
    ["The news lady looked scared"] = "La de las noticias se veía asustada",
    ["Nobody at work knows anything"] = "En el trabajo nadie sabe nada",
    ["Saw a man walking down the middle of the road. Something wrong with him"] =
        "Vi a un hombre caminando a media calle. Algo raro le pasaba",
    ["Stay off 31W"] = "No tomes la 31W",
    ["They closed the roads at 6 this morning"] = "Cerraron las carreteras a las 6 de la mañana",
    ["Soldiers at the bridge"] = "Soldados en el puente",
    ["The house phone is dead"] = "El teléfono de la casa no sirve",
    ["This is the only thing that works now"] = "Esto es lo único que funciona ya",
    ["Curfew at dark"] = "Toque de queda al anochecer",
    ["Fence going up by the highway"] = "Están poniendo una cerca junto a la carretera",
    ["Neighbors left last night"] = "Los vecinos se fueron anoche",
    ["Heard shooting by the school"] = "Se oyeron disparos por la escuela",
    ["Power keeps flickering"] = "La luz sigue parpadeando",
    ["We're at the church"] = "Estamos en la iglesia",
    ["Running low on [milk|bread|everything]"] = "Se nos está acabando [la leche|el pan|todo]",
    ["On the roof for one bar"] = "Subí al techo por una rayita de señal",
    ["Charging the phone in the truck"] = "Cargando el teléfono en la camioneta",
    ["The water tastes funny"] = "El agua sabe rara",
    ["Boarded the back windows"] = "Tapamos las ventanas de atrás",
    ["Somebody's knocking on doors down the street"] = "Alguien está tocando puertas más abajo en la calle",
    ["They won't let anybody out of {town}"] = "No dejan salir a nadie de {town}",
    ["Lock your doors"] = "Cierra con llave",
    ["Nobody's seen the mailman in two days"] = "Nadie ha visto al cartero en dos días",
    ["The Army says supplies are coming. Sure"] = "El Ejército dice que vienen provisiones. Sí, claro",
    ["Where are you"] = "Dónde estás",
    ["Please answer"] = "Por favor contesta",
    ["Call me"] = "Llámame",
    ["Are you ok"] = "Estás bien",
    ["I'm worried"] = "Me preocupas",
    ["Your [car|truck] is still out front"] = "[Tu auto|Tu camioneta] sigue afuera",
    ["I went by your place"] = "Pasé por tu casa",
    ["Nobody's heard from you"] = "Nadie sabe nada de ti",
    ["Just one word"] = "Solo una palabra",
    ["Mom keeps asking"] = "Mamá sigue preguntando",
    ["The church has a list. You're not on it"] = "La iglesia tiene una lista. No estás",
    ["I'm not mad"] = "No me enojo",
    ["It's getting dark"] = "Está oscureciendo",
    ["I'll keep trying"] = "Voy a seguir intentando",
    ["Text me back"] = "Contéstame",
    ["I fed your [dog|cat]"] = "Le di de comer a tu [perro|gato]",
    ["Come home"] = "Ven a casa",
    ["We're still here"] = "Seguimos aquí",
    ["Can you cover [Saturday|Sunday]"] = "Puedes cubrir el [sábado|domingo]",
    ["Schedule's posted"] = "Ya está el horario",
    ["Your check is in the office"] = "Tu cheque está en la oficina",
    ["Truck comes at six tomorrow"] = "El camión llega mañana a las seis",
    ["Somebody called in sick again"] = "Alguien se reportó enfermo otra vez",
    ["Safety meeting [Monday|Wednesday]"] = "Reunión de seguridad el [lunes|miércoles]",
    ["Closing early today"] = "Hoy cerramos temprano",
    ["Half the crew didn't show"] = "Faltó la mitad del personal",
    ["Corporate says stay open"] = "La empresa dice que sigamos abiertos",
    ["Don't come in after three"] = "No vengas después de las tres",
    ["Stay home if you can"] = "Quédate en casa si puedes",
    ["Closed until further notice"] = "Cerrado hasta nuevo aviso",
    ["Don't come in"] = "No vengas",
    ["Your last check is in the drop box"] = "Tu último cheque está en el buzón",
    ["Locking up for good"] = "Cerramos para siempre",
    ["Take care of your family"] = "Cuida a tu familia",
    ["You didn't come in today"] = "Hoy no viniste",
    ["We kept your spot"] = "Te guardamos el puesto",
    ["Just let us know you're ok"] = "Solo avísanos que estás bien",
    ["Love you"] = "Te quiero",
    ["Just saying"] = "Solo digo",
    ["Ha"] = "Ja",
    ["Talk later"] = "Hablamos luego",
    ["Be careful"] = "Ten cuidado",
    ["Stay inside"] = "Quédate adentro",
    ["Please call"] = "Por favor llama",
    ["Stay put"] = "No te muevas",
    ["Text don't call"] = "Escribe, no llames",
    ["Please"] = "Por favor",
    ["Anything"] = "Lo que sea",

    -- Your family picks up (Core/FamilyCall) -------------------------------------------------------------------
    ["{label}: {you}? Oh thank God. Where are you? / Hello? You're breaking up. / Text me. Texts get through."] =
        "{label}: ¿{you}? Gracias a Dios. ¿Dónde estás? / ¿Hola? Se corta. / Mándame un mensaje. Los mensajes sí llegan.",
    ["{label}: Are you okay? The TV says stay inside and lock the doors. / I can barely hear you. / I love you. Text me."] =
        "{label}: ¿Estás bien? En la tele dicen que nos quedemos adentro con las puertas cerradas. / Casi no te oigo. / Te quiero. Escríbeme.",
    ["{label}: I've been calling and calling. Don't go outside. / (the line crackles and goes dead)"] =
        "{label}: Te he llamado y llamado. No salgas. / (la línea chisporrotea y se corta)",
    ["{label}: Hey, kiddo. We're okay. The power keeps going out. / Do you have food? Water? / Hello? ..."] =
        "{label}: Hola, mi cielo. Estamos bien. Se sigue yendo la luz. / ¿Tienes comida? ¿Agua? / ¿Hola? ...",
    ["{label}: Don't hang up! I don't know how long this line lasts. / Stay off the roads. They're blocked. / (static)"] =
        "{label}: ¡No cuelgues! No sé cuánto dure la línea. / No salgas a la carretera. Está bloqueada. / (estática)",
    ["{label}: Is that you? I can't hear a thing. / If you can hear me, we're all right. Text, don't call."] =
        "{label}: ¿Eres tú? No oigo nada. / Si me oyes, estamos bien. Escribe, no llames.",
    ["{label}: {you}. Okay. Okay. You're alive. / Fill the bathtub while the water's on. / I have to go, the battery."] =
        "{label}: {you}. Bueno. Bueno. Sigues con vida. / Llena la tina mientras haya agua. / Tengo que colgar, la batería.",
    ["{label}: Did you eat today? Don't lie to me. / There's soup in the pantry if you get home. / Love you. Bye."] =
        "{label}: ¿Comiste hoy? No me mientas. / Hay sopa en la alacena si llegas a casa. / Te quiero. Adiós.",
    ["{label}: We heard shooting last night. Over by the school. / Keep your curtains shut at night. / (the call drops)"] =
        "{label}: Oímos disparos anoche. Por la escuela. / Mantén las cortinas cerradas de noche. / (se corta la llamada)",
    ["{label}: I keep trying the house phone. Nothing. / This is the only thing that works now. Keep it charged."] =
        "{label}: Sigo intentando con el teléfono de la casa. Nada. / Esto es lo único que funciona ya. Mantenlo cargado.",
    ["{label}: The neighbors left this morning. Just packed up and went. / Don't open the door for anybody. Promise me."] =
        "{label}: Los vecinos se fueron esta mañana. Empacaron y se fueron. / No le abras la puerta a nadie. Prométemelo.",
    ["{label}: Hold on, the dog's barking at something. / ... it's nothing. I think it's nothing. / Text me tonight."] =
        "{label}: Espera, el perro le está ladrando a algo. / ... no es nada. Creo que no es nada. / Escríbeme esta noche.",
    ["{label}: I went to the IGA. The shelves are empty, {you}. / We've got enough for a week. Then I don't know."] =
        "{label}: Fui al IGA. Los estantes están vacíos, {you}. / Tenemos para una semana. Después no sé.",
    ["{label}: Your cousin called from Louisville. They're not letting anybody out. / Stay where you are."] =
        "{label}: Tu primo llamó desde Louisville. No están dejando salir a nadie. / Quédate donde estás.",
    ["{label}: I'm on the roof, it's the only place I get a bar. / Can you hear me? / Good. Good."] =
        "{label}: Estoy en el techo, es el único lugar donde tengo señal. / ¿Me oyes? / Bien. Bien.",
    ["{label}: The church opened its doors to anybody who needs it. / We might go there. I'll text you. / (static)"] =
        "{label}: La iglesia abrió sus puertas para quien lo necesite. / Tal vez vayamos. Te escribo. / (estática)",
    ["{label}: We're at {place}. Come when it's safe. / Don't call, the lines are jammed. Text."] =
        "{label}: Estamos en {place}. Ven cuando sea seguro. / No llames, las líneas están saturadas. Escribe.",
    ["{label}: {you}! We made it to {place}. / Bring water if you can. Be careful out there."] =
        "{label}: ¡{you}! Llegamos a {place}. / Trae agua si puedes. Cuídate allá afuera.",
    ["{label}: We're holed up at {place}. Doors locked. / Come at daylight, not after dark. / Knock and say your name."] =
        "{label}: Estamos encerrados en {place}. Puertas con llave. / Ven de día, no de noche. / Toca y di tu nombre.",
    ["{label}: It's crowded at {place} but it's safe. Mostly. / There's room for you. Please come."] =
        "{label}: Hay mucha gente en {place} pero es seguro. Casi. / Hay lugar para ti. Por favor ven.",
    ["{label}: {place}. Remember it. {place}. / Take the back roads. The highway's blocked."] =
        "{label}: {place}. Acuérdate. {place}. / Toma los caminos de atrás. La carretera está bloqueada.",
    ["{label}: We moved to {place} last night. / Somebody's got a generator. We're okay. / Hurry if you can."] =
        "{label}: Nos fuimos a {place} anoche. / Alguien tiene un generador. Estamos bien. / Apúrate si puedes.",
    ["{label}: I wrote it on the fridge for you too. {place}. / In case your phone dies. / Come find us."] =
        "{label}: También te lo escribí en el refri. {place}. / Por si se te muere el teléfono. / Ven a buscarnos.",
    ["{label}: We're at {place}. Your father boarded the windows. / Bring your blankets. It gets cold at night."] =
        "{label}: Estamos en {place}. Tu papá tapó las ventanas. / Trae tus cobijas. Hace frío de noche.",
    ["{label}: (coughing) I'm okay, honey. Just a fever. / Don't come here yet. / I need to lie down."] =
        "{label}: (tosiendo) Estoy bien, cariño. Solo es fiebre. / No vengas todavía. / Necesito acostarme.",
    ["{label}: One of them scratched me. It's nothing. / I'm so tired. Call you tomorrow, okay?"] =
        "{label}: Uno de ellos me rasguñó. No es nada. / Tengo tanto sueño. Te llamo mañana, ¿sí?",
    ["{label}: I'm burning up, {you}. It's just the flu. / Everybody's got it. / Don't worry about me."] =
        "{label}: Estoy ardiendo en fiebre, {you}. Es solo la gripe. / Todos la tienen. / No te preocupes por mí.",
    ["{label}: Sorry, I fell asleep. What day is it? / ... okay. Okay. I'll call you later."] =
        "{label}: Perdón, me ganó el sueño. ¿Qué día es? / ... bueno. Bueno. Te llamo luego.",
    ["{label}: Don't come here. I mean it. / Stay where you are and keep the door locked. / I love you."] =
        "{label}: No vengas aquí. Lo digo en serio. / Quédate donde estás y con la puerta cerrada con llave. / Te quiero.",
    ["{label}: My arm hurts but it's fine. I wrapped it. / Did you eat? / I'm going to rest a little."] =
        "{label}: Me duele el brazo pero está bien. Lo vendé. / ¿Comiste? / Voy a descansar un poco.",
    ["{label}: I can't keep anything down. / The others are staying in the other room. It's better. / Talk tomorrow."] =
        "{label}: No retengo nada. / Los demás se quedan en el otro cuarto. Es mejor. / Hablamos mañana.",
    ["{label}: (a long breath) Hi, sweetheart. / I'm just tired. I'm so tired. / Tell me something nice."] =
        "{label}: (un respiro largo) Hola, corazón. / Solo es cansancio. Mucho cansancio. / Cuéntame algo bonito.",
    ["{label}: (breathing hard) Don't... don't come here. / Remember the good stuff, okay? / (silence)"] =
        "{label}: (respirando con dificultad) No... no vengas. / Acuérdate de lo bueno, ¿sí? / (silencio)",
    ["{label}: {you}. I wanted to hear you. That's all. / Don't come. Promise. / (the line stays open, then nothing)"] =
        "{label}: {you}. Quería oírte. Nada más. / No vengas. Prométemelo. / (la línea sigue abierta, luego nada)",
    ["{label}: I'm sitting by the window. It's a pretty night. / You were always my favorite. Don't tell. / (silence)"] =
        "{label}: Estoy junto a la ventana. Es una noche bonita. / Siempre te quise un poquito más. No le digas a nadie. / (silencio)",
    ["{label}: Remember the lake? The summer you learned to swim? / Think about that, okay? Not this. / (silence)"] =
        "{label}: ¿Te acuerdas del lago? ¿El verano en que aprendiste a nadar? / Piensa en eso, ¿sí? No en esto. / (silencio)",
    ["{label}: They've got us on a bus. The Army. I don't know where to. / I love you. Stay alive."] =
        "{label}: Nos subieron a un autobús. El Ejército. No sé a dónde. / Te quiero. Sigue con vida.",
    ["{label}: Soldiers came. We're in a truck. They won't say where. / I'll find you. I swear I'll find you."] =
        "{label}: Vinieron unos soldados. Vamos en un camión. No dicen a dónde. / Te voy a encontrar. Te juro que te voy a encontrar.",
    ["{label}: We're out! They took us past the fence. / They wouldn't wait. I'm sorry, {you}. I'm so sorry."] =
        "{label}: ¡Salimos! Nos llevaron al otro lado de la cerca. / No quisieron esperar. Lo siento, {you}. Lo siento tanto.",
    ["{label}: It's a camp. Cots and a tent. They check everybody. / Stay alive. They'll come back for more."] =
        "{label}: Es un campamento. Catres y una carpa. Revisan a todos. / Sigue con vida. Van a volver por más.",
    ["{label}: We're leaving. I left you a note at {place}. / I'm sorry. Find us."] =
        "{label}: Nos vamos. Te dejé una nota en {place}. / Lo siento. Búscanos.",
    ["{label}: We couldn't wait any longer. There's food at {place}. / We love you. Come find us."] =
        "{label}: No pudimos esperar más. Hay comida en {place}. / Te queremos. Ven a buscarnos.",
    ["{label}: I left the key where we always do. At {place}. / We had to go. Please understand."] =
        "{label}: Dejé la llave donde siempre. En {place}. / Tuvimos que irnos. Por favor entiende.",
    ["{label}: This is goodbye for now. Not forever. / Look for us. Don't stop looking."] =
        "{label}: Esto es un adiós por ahora. No para siempre. / Búscanos. No dejes de buscar.",
    ["Hi, you've reached {first}. I can't get to the phone. Leave a message. / (beep)"] =
        "Hola, habla {first}. No puedo contestar. Deja un mensaje. / (bip)",
    ["This is {first}. Leave your name and number after the beep. / (beep)"] =
        "Soy {first}. Deja tu nombre y número después del tono. / (bip)",
    ["{first} here. Well, not here. You know what to do. / (beep)"] = "Aquí {first}. Bueno, no aquí. Ya sabes qué hacer. / (bip)",
    ["The person you are calling is not available. Please leave a message after the tone. / (beep)"] =
        "La persona a la que llama no está disponible. Por favor deje un mensaje después del tono. / (bip)",

    -- Your family texts back (Core/FamilyText)
    ["Hurt where?? Wash it right now. Hot water and soap, and wrap it tight"] =
        "¿¿Dónde te lastimaste?? Lávalo ahora mismo. Agua caliente y jabón, y véndalo bien",
    ["What happened? Is it a bite? Tell me it's not a bite"] = "¿Qué pasó? ¿Es una mordida? Dime que no es una mordida",
    ["Breathe. Get somewhere with a door that locks and stay quiet"] =
        "Respira. Métete en algún lugar con una puerta que cierre con llave y no hagas ruido",
    ["I'm right here. Stay away from the windows and keep the lights off"] =
        "Aquí estoy. Aléjate de las ventanas y deja las luces apagadas",
    ["Still home. [We're not going anywhere till this calms down|The roads are a mess]"] =
        "Seguimos en casa. [No vamos a ningún lado hasta que esto se calme|Las carreteras son un desastre]",
    ["Home, with the doors locked. Where else would we be"] = "En casa, con las puertas cerradas con llave. Dónde más íbamos a estar",
    ["We're at {place}. Come in daylight, not after dark"] = "Estamos en {place}. Ven de día, no de noche",
    ["Still at {place}. Knock and say your name"] = "Seguimos en {place}. Toca y di tu nombre",
    ["Not in the dark. Wait for daylight and take the back roads"] =
        "De noche no. Espera a que amanezca y toma los caminos de atrás",
    ["Only if it's safe. Don't you dare take the highway"] = "Solo si es seguro. Ni se te ocurra tomar la carretera",
    ["What's wrong? Talk to me"] = "¿Qué pasa? Háblame",
    ["Not okay how? Are you hurt? Tell me the truth"] = "¿Cómo que no estás bien? ¿Te lastimaste? Dime la verdad",
    ["We're okay. Scared, but okay"] = "Estamos bien. Con miedo, pero bien",
    ["We're fine for now. Are YOU okay? That's what matters"] = "Estamos bien por ahora. ¿TÚ estás bien? Eso es lo que importa",
    ["Oh thank God. I've been sick with worry"] = "Gracias a Dios. La preocupación me estaba matando",
    ["Okay. Okay. That's the best thing I've heard all day"] = "Bueno. Bueno. Es lo mejor que he oído en todo el día",
    ["Good. Stay that way. Don't take chances"] = "Qué bien. Sigue así. No te arriesgues",
    ["Love you too. So much"] = "Yo también te quiero. Muchísimo",
    ["Miss you like crazy. We'll be together soon"] = "Te extraño muchísimo. Pronto vamos a estar juntos",
    ["Eat what you've got and fill every pot with water while it still runs"] =
        "Come lo que tengas y llena todas las ollas de agua mientras haya",
    ["There's canned stuff in every house. Don't be proud about it"] = "Hay latas en todas las casas. No es momento de orgullo",
    ["Are you somewhere safe? Lock every door"] = "¿Estás en un lugar seguro? Cierra todas las puertas con llave",
    ["The TV just says stay inside. Nobody knows anything"] = "La tele solo dice que nos quedemos adentro. Nadie sabe nada",
    ["Keep your phone charged. Text me every few hours, okay?"] = "Mantén el teléfono cargado. Escríbeme cada tantas horas, ¿sí?",
    ["We're trying to get the radio working"] = "Estamos tratando de hacer funcionar la radio",
    ["Don't go outside after dark. Please"] = "No salgas de noche. Por favor",
    ["I keep hearing sirens. [It won't stop|All night]"] = "Sigo oyendo sirenas. [No paran|Toda la noche]",
    ["Calls won't go through. Texts are better"] = "Las llamadas no entran. Mejor mensajes",
    ["Did you eat today? Don't lie to me"] = "¿Comiste hoy? No me mientas",
    ["We've got water and canned stuff. We're okay for now"] = "Tenemos agua y latas. Estamos bien por ahora",
    ["The neighbors aren't answering their door"] = "Los vecinos no abren la puerta",
    ["Stay off the main roads. They're saying the highway's blocked"] =
        "No vayas por las calles principales. Dicen que la carretera está bloqueada",
    ["Fill the tub while the water's still on"] = "Llena la tina mientras todavía haya agua",
    ["Text me when you wake up. I love you"] = "Escríbeme cuando despiertes. Te quiero",
    ["Is anyone with you? Don't be alone if you can help it"] = "¿Hay alguien contigo? Que no estés sin nadie si se puede",
    ["The power flickered again. [Writing this by candle|Saving the battery]"] =
        "La luz parpadeó otra vez. [Te escribo con una vela|Ahorrando batería]",
    ["Please be careful. I can't lose you"] = "Por favor ten cuidado. No te puedo perder",
    ["This is insane. Are you seeing the news?"] = "Esto es una locura. ¿Estás viendo las noticias?",
    ["Mom keeps calling me. Text her too ok"] = "Mamá no deja de llamarme. Escríbele a ella también ok",
    ["Stay inside. I mean it. People are losing it out there"] = "Quédate adentro. En serio. La gente se está volviendo loca allá afuera",
    ["Phone's almost dead. Saving it. Text me later"] = "El teléfono casi no tiene batería. Lo estoy ahorrando. Escríbeme luego",
    ["I saw one up close. Can't stop shaking"] = "Vi uno de cerca. No paro de temblar",
    ["Don't do anything stupid. I need you around"] = "No hagas ninguna estupidez. Te necesito",
    ["Lines are jammed. Texting is the only thing that works"] = "Las líneas están saturadas. Los mensajes son lo único que funciona",
    ["Remember when we thought the end of the world would be cool? It isn't"] =
        "¿Te acuerdas cuando pensábamos que el fin del mundo sería genial? No lo es",
    ["We're at {place}. Come when it's light"] = "Estamos en {place}. Ven cuando sea de día",
    ["Still at {place}. We're okay here. Bring water if you can"] = "Seguimos en {place}. Aquí estamos bien. Trae agua si puedes",
    ["{place}. Remember it. Take the back roads"] = "{place}. Acuérdate. Toma los caminos de atrás",
    ["Sorry, slept all day. The fever's bad. Don't worry"] = "Perdón, dormí todo el día. La fiebre está fuerte. No te preocupes",
    ["I'm okay. Just tired. So tired"] = "Estoy bien. Solo cansancio. Mucho cansancio",
    ["Don't come here yet. I don't want you catching this"] = "No vengas todavía. No quiero que te contagies",
    ["My arm's swollen where it got me. Wrapped it. It's fine"] = "Tengo el brazo hinchado donde me agarró. Lo vendé. Está bien",
    ["Can't keep anything down. Talk tomorrow ok?"] = "No retengo nada. Hablamos mañana ok?",

    -- Texting back a dead owner's people (Core/Replies) --------------------------------------------------------
    ["KNOX MOBILE: Message not delivered. The number you are texting can't be reached."] =
        "KNOX MOBILE: Mensaje no entregado. No se puede contactar al número al que escribes.",
    ["{owner}?? Oh thank God. Where are you"] = "¿¿{owner}?? Gracias a Dios. Dónde estás",
    ["{owner} is that you? Call me. Please call me"] = "{owner} eres tú? Llámame. Por favor llámame",
    ["Oh my God. {owner}. Are you ok? Are you hurt?"] = "Dios mío. {owner}. ¿Estás bien? ¿Te pasó algo?",
    ["Finally. Where ARE you? Are you safe?"] = "Por fin. ¿Dónde ESTÁS? ¿Estás a salvo?",
    ["{owner}! We've been texting for days. Where are you"] = "¡{owner}! Llevamos días mandándote mensajes. Dónde estás",
    ["Is this {owner}? Please say it's you"] = "¿Eres {owner}? Por favor dime que eres tú",
    ["Why won't you call. This isn't {owner}, is it."] = "Por qué no llamas. No eres {owner}, ¿verdad?",
    ["Who is this. Why do you have {owner}'s phone."] = "Quién eres. Por qué tienes el teléfono de {owner}.",
    ["Please just tell me. Is {owner} alive?"] = "Por favor solo dime. ¿{owner} sigue con vida?",
    ["You're not {owner}. {owner} never writes like that."] = "Tú no eres {owner}. {owner} nunca escribe así.",
    ["I need you to tell me the truth. Where did you find this phone."] =
        "Necesito que me digas la verdad. Dónde encontraste este teléfono.",
    ["Ok. Thank you for telling me. I think I knew."] = "Ok. Gracias por decírmelo. Creo que ya lo sabía.",
    ["I'm not going to ask how. Please don't tell me how."] = "No voy a preguntar cómo. Por favor no me digas cómo.",
    ["Thank you for keeping it on. I needed to know."] = "Gracias por dejarlo encendido. Necesitaba saberlo.",
    ["Ok. Ok. I'm going to sit down for a while."] = "Ok. Ok. Me voy a sentar un rato.",
    ["I knew when the texts stopped going through. Thank you for being honest."] =
        "Lo supe cuando los mensajes dejaron de llegar. Gracias por tu honestidad.",
    ["Are you still there?"] = "¿Sigues ahí?",
    ["Keep the phone charged if you can. I like seeing it go through."] =
        "Mantén el teléfono cargado si puedes. Me gusta ver que los mensajes llegan.",
    ["Tell me something about where you are. Anything."] = "Cuéntame algo de donde estás. Lo que sea.",
    ["Still here. Still breathing. You?"] = "Sigo aquí. Sigo respirando. ¿Y tú?",
    ["I read the old messages every night."] = "Leo los mensajes viejos todas las noches.",
    ["Be careful out there. I mean it."] = "Cuídate allá afuera. En serio.",
    ["Did you find anything of {owner}'s? You don't have to answer."] = "¿Encontraste algo de {owner}? No tienes que contestar.",
    ["{owner}? Is that you? Nobody's heard from anyone at work."] = "¿{owner}? ¿Eres tú? Nadie sabe nada de nadie del trabajo.",
    ["{owner}, if you get this, don't come in. There's nothing left to come in to."] =
        "{owner}, si te llega esto, no vengas. Ya no queda nada a qué venir.",
    ["Who is this."] = "Quién eres.",
    ["That's not {owner}."] = "Tú no eres {owner}.",
    ["Who's on {owner}'s phone."] = "Quién tiene el teléfono de {owner}.",
    ["Where'd you get that phone."] = "De dónde sacaste ese teléfono.",
    ["That's {owner}'s phone. Where'd you get it."] = "Ese es el teléfono de {owner}. De dónde lo sacaste.",
    ["You were there when it happened?"] = "¿Estabas ahí cuando pasó?",
    ["Keep it. We know what it sounds like when it rings."] = "Quédatelo. Sabemos cómo suena cuando timbra.",
    ["We'll find you."] = "Te vamos a encontrar.",
    ["Don't text this number again."] = "No vuelvas a escribir a este número.",
    ["We left a bag at {place} on the way out. Take it. Somebody should have it."] =
        "Dejamos una bolsa en {place} al salir. Llévatela. Alguien debería aprovecharla.",
    ["There's a bag at {place}. We couldn't carry it. It's yours."] = "Hay una bolsa en {place}. No pudimos cargarla. Es tuya.",
    ["If you're near {place}, we hid a bag there. Take it. Don't be a hero about it."] =
        "Si estás cerca de {place}, escondimos una bolsa ahí. Llévatela. Sin heroísmos.",
    ["Our house was {home}. If you ever pass it, would you leave the phone there? It should be home."] =
        "Nuestra casa era {home}. Si alguna vez pasas por ahí, ¿dejarías el teléfono? Debería estar en casa.",
    ["{owner} lived at {home}. Leave the phone there if you can. I'd like to think of it there."] =
        "{owner} vivía en {home}. Deja el teléfono ahí si puedes. Me gustaría pensar que está ahí.",
    ["If you're ever by {home}, that was ours. Put the phone inside. Please."] =
        "Si alguna vez pasas por {home}, era nuestra. Deja el teléfono adentro. Por favor.",
    ["One thing. {home}. That's home. If you're near it, take the phone back for me."] =
        "Una cosa. {home}. Esa es nuestra casa. Si estás cerca, lleva el teléfono de vuelta por mí.",

    -- Wrong numbers and forwarded rumors (Core/Strangers) ------------------------------------------------------
    ["Is this Carl? Tell Carl the truck is at the quarry. He'll know."] =
        "¿Eres Carl? Dile a Carl que la camioneta está en la cantera. Él sabrá.",
    ["Mama it's Tisha. This is Darnell's phone. Mine died. Where are you"] =
        "Mami soy Tisha. Este es el teléfono de Darnell. El mío se murió. Dónde estás",
    ["Did you get the generator going? It's Bobby. Call me"] = "¿Pudiste arrancar el generador? Soy Bobby. Llámame",
    ["who is this. you called this number twice last night"] = "quién es. llamaste a este número dos veces anoche",
    ["Sorry wrong number. If you're near Riverside don't take 31W."] =
        "Perdón, número equivocado. Si estás cerca de Riverside no tomes la 31W.",
    ["Dad? Is this still your number?"] = "¿Papá? ¿Este sigue siendo tu número?",
    ["This is for Pastor Jim. We have six at the house now. Can you take more?"] =
        "Esto es para el pastor Jim. Ya somos seis en la casa. ¿Puedes recibir a más?",
    ["Rachel I'm at your mom's. Nobody's here. The door was open."] =
        "Rachel estoy en casa de tu mamá. No hay nadie. La puerta estaba abierta.",
    ["hey is this the guy with the boat"] = "oye eres el del bote",
    ["Marcy said you have insulin. I can trade batteries. Please."] = "Marcy dijo que tienes insulina. Te cambio pilas. Por favor.",
    ["Kevin pick up your phone. KEVIN."] = "Kevin contesta el teléfono. KEVIN.",
    ["Stop texting me. I don't know you. I don't know where your sister is."] =
        "Deja de mandarme mensajes. No te conozco. No sé dónde está tu hermana.",
    ["If anybody gets this. Two adults, one kid, Lime St. We're ok for now."] =
        "Si alguien recibe esto. Dos adultos, un niño, Lime St. Estamos bien por ahora.",
    ["is this 555-0190? the radio said to text this number to get on the list"] =
        "es el 555-0190? la radio dijo que mandáramos mensaje a este número para entrar a la lista",
    ["Wrong number probably. But hi. It's nice to send a text to somebody."] =
        "Número equivocado seguro. Pero hola. Se siente bien mandarle un mensaje a alguien.",
    ["Tell Ray I'm sorry about the truck"] = "Dile a Ray que perdón por lo de la camioneta",
    ["Who has Dennis's phone? This is his brother."] = "¿Quién tiene el teléfono de Dennis? Soy su hermano.",
    ["Uncle Pete it's me, we made it to Louisville. Don't come. The bridge is closed"] =
        "Tío Pete soy yo, llegamos a Louisville. No vengas. El puente está cerrado",
    ["Did the army come by your street yet"] = "Ya pasó el ejército por tu calle",
    ["This is the Knox Mobile store on Main. We're closed. Don't come in for your phone."] =
        "Habla la tienda Knox Mobile de Main. Estamos cerrados. No venga por su teléfono.",
    ["Grandma if you get this the pills are in the blue bag"] = "Abuela si te llega esto las pastillas están en la bolsa azul",
    ["it's Shawna. new number. old phone got wet. tell everybody"] =
        "soy Shawna. número nuevo. el otro teléfono se mojó. avísales a todos",
    ["Is this the number for the shelter at the school?"] = "¿Es el número del refugio de la escuela?",
    ["We're leaving tonight. If you want to come, be at the church at 6."] =
        "Nos vamos esta noche. Si quieres venir, estate en la iglesia a las 6.",
    ["FWD: "] = "RV: ",
    ["FWD FWD: "] = "RV RV: ",
    ["pass it on: "] = "pásalo: ",
    ["got this from a friend: "] = "me lo mandó un amigo: ",

    -- An A-Life crew's phones (Core/FactionChatter, Data/WireLines) --------------------------------------------
    ["Patrol leaves at [dawn|first light|dusk]. {mate}, you're on point"] =
        "La patrulla sale [al amanecer|con la primera luz|al atardecer]. {mate}, tú vas adelante",
    ["Supply run to the [pharmacy|gas station|IGA] tomorrow. Bring every bag you have"] =
        "Salida por provisiones [a la farmacia|a la gasolinera|al IGA] mañana. Traigan todas las bolsas que tengan",
    ["Saw [three|a few|a lot] of them by the [creek|tracks|highway]. Stay off that road"] =
        "Vi a [tres|unos cuantos|muchos] de ellos por [el arroyo|las vías|la carretera]. No usen ese camino",
    ["{mate} has watch tonight. Nobody else goes past the fence"] = "{mate} hace guardia esta noche. Nadie más pasa la cerca",
    ["Somebody's been in the stash. Count everything"] = "Alguien se metió al escondite. Cuenten todo",
    ["Strangers on the west road. Armed. Don't start anything"] = "Desconocidos en el camino del oeste. Armados. No empiecen nada",
    ["Trade meet at the [bridge|church|old school] at noon. Ammo, not cash"] =
        "Trueque en [el puente|la iglesia|la escuela vieja] al mediodía. Munición, no dinero",
    ["{mate2} got scratched. Says it's nothing. Keep an eye on them"] =
        "{mate2} tiene un rasguño. Dice que no es nada. No le quiten el ojo",
    ["Generator stays off after dark. They hear it"] = "El generador se queda apagado de noche. Lo oyen",
    ["Two new faces asking to join. We vote tonight"] = "Dos caras nuevas quieren unirse. Votamos esta noche",
    ["Water's low. Whoever's near the creek, fill the jugs"] = "Queda poca agua. Quien esté cerca del arroyo, llene los garrafones",
    ["Radio's dead again. Use these phones while the towers last"] =
        "La radio murió otra vez. Usen estos teléfonos mientras duren las antenas",
    ["Nobody goes out alone. I mean it"] = "Nadie sale sin compañía. En serio",
    ["Found a car with half a tank on Main. {mate} is siphoning it"] =
        "Encontramos un auto con medio tanque en Main. {mate} le está sacando la gasolina",
    ["The house past the creek has lights at night. Somebody's living there"] =
        "La casa pasando el arroyo tiene luces de noche. Alguien vive ahí",
    ["If anybody sees a [red|white] pickup, that's not us. Hide"] =
        "Si alguien ve una camioneta [roja|blanca], no somos nosotros. Escóndanse",
    ["We're moving the stash tomorrow. Don't ask where yet"] = "Mañana movemos el escondite. No pregunten adónde todavía",
    ["Good haul today. Canned peaches. Don't eat them all, {mate}"] =
        "Buen botín hoy. Duraznos en lata. No te los comas todos, {mate}",
    ["Fire on the ridge last night. Not ours"] = "Fuego en la loma anoche. No era nuestro",
    ["Boards on every downstairs window by tonight"] = "Tablas en todas las ventanas de abajo para esta noche",
    ["{mate} found a dog. We're keeping it apparently"] = "{mate} encontró un perro. Al parecer nos lo quedamos",
    ["Somebody left the gate open. Again"] = "Alguien dejó el portón abierto. Otra vez",
    ["Heard engines on the highway. Army or worse. Stay low"] = "Se oyen motores en la carretera. El ejército o algo peor. Agáchense",
    ["Meeting at the fire after dark. Everybody"] = "Reunión junto al fuego al anochecer. Todos",
    ["{owner}, where are you? You were supposed to be back by dark"] =
        "{owner}, ¿dónde estás? Tenías que volver antes de que oscureciera",
    ["Anybody seen {owner}?"] = "¿Alguien ha visto a {owner}?",
    ["{owner} went out [this morning|before noon] and didn't come back"] = "{owner} salió [esta mañana|antes del mediodía] y no volvió",
    ["{mate}, take {owner}'s watch tonight"] = "{mate}, cubre la guardia de {owner} esta noche",
    ["Don't go looking for {owner} alone"] = "Que nadie vaya a buscar a {owner} sin compañía",
    ["If {owner} is out there, [the gate's unlocked|we left the porch light on]"] =
        "Si {owner} anda por ahí, [el portón está abierto|dejamos la luz del porche encendida]",
    ["We'll go out for {owner} at first light"] = "Saldremos a buscar a {owner} con la primera luz",
    ["Stop texting {owner}. Please"] = "Dejen de escribirle a {owner}. Por favor",
    ["u on watch tonight or me"] = "te toca guardia hoy o a mi",
    ["bring the good flashlight"] = "trae la linterna buena",
    ["dont tell the others about the peaches"] = "no les digas a los demás de los duraznos",
    ["meet me by the fence after"] = "te veo junto a la cerca después",
    ["you see that pickup earlier?"] = "viste esa camioneta hace rato?",
    ["save me a spot by the fire"] = "apártame un lugar junto al fuego",
    ["my feet are killing me. trade boots?"] = "me matan los pies. cambiamos botas?",
    ["we good after this morning?"] = "estamos bien después de lo de esta mañana?",
    ["come back. we'll figure it out"] = "regresa. ya veremos cómo",
    ["they're saying you're gone. tell me they're wrong"] = "dicen que ya no estás. dime que se equivocan",
    ["i kept your stuff"] = "guardé tus cosas",
    ["answer me"] = "contéstame",
    ["i'm sorry about what i said"] = "perdón por lo que dije",
    ["Out for supplies near {town}."] = "Saliendo por provisiones cerca de {town}.",
    ["Hitting houses by {town}. Back before dark."] = "Revisando casas por {town}. Vuelvo antes de que oscurezca.",
    ["Supply run, {town}. Keep the radio on."] = "Salida por provisiones, {town}. Dejen la radio prendida.",
    ["Going through a street by {town}. Slim pickings."] = "Revisando una calle por {town}. No hay mucho.",
    ["Boarding up the windows here."] = "Tapando las ventanas aquí.",
    ["Nailing up the back. Need more boards."] = "Clavando la parte de atrás. Faltan tablas.",
    ["Doing the doors now. Bring nails if you've got them."] = "Ahora las puertas. Traigan clavos si tienen.",
    ["Watching the road out of {town}."] = "Vigilando la salida de {town}.",
    ["Quiet out here."] = "Todo tranquilo aquí.",
    ["On watch. Nothing moving yet."] = "De guardia. Nada se mueve todavía.",
    ["Eyes on the road by {town}."] = "Vigilando el camino por {town}.",
    ["Too many of them by {town}. Going around."] = "Demasiados por {town}. Voy a rodear.",
    ["Got company. Moving."] = "Tengo compañía. Me muevo.",
    ["Whole crowd of them near {town}. Stay clear."] = "Una multitud de ellos cerca de {town}. Manténganse lejos.",
    ["Taking five."] = "Descansando cinco.",
    ["Need a breather."] = "Necesito un respiro.",
    ["Sitting down for a minute. Feet are done."] = "Me siento un minuto. Ya no doy más de los pies.",
    ["Back with a bag. Somebody count it."] = "De vuelta con una bolsa. Que alguien la cuente.",
    ["Dropped the haul at the house."] = "Dejé el botín en la casa.",
    ["Brought back what I could carry."] = "Traje lo que pude cargar.",
    ["Made it back."] = "Ya volví.",
    ["I'm in. Door's shut."] = "Ya entré. Puerta cerrada.",
    ["Home. Somebody put the coffee on."] = "En casa. Que alguien ponga el café.",
    ["Anybody on? Check in."] = "¿Alguien en línea? Repórtense.",
    ["Roll call. Answer when you can."] = "Pasando lista. Contesten cuando puedan.",
    ["Everybody check in before dark."] = "Todos repórtense antes de que oscurezca.",
    ["{mate} got hurt. Patching them up."] = "{mate} se lastimó. Estoy curando la herida.",
    ["Need the med bag. {mate}'s bleeding."] = "Necesito el botiquín. {mate} está sangrando.",
    ["Stopped somebody on the road by {town}. They're handing it over."] =
        "Paramos a alguien en el camino por {town}. Está entregando todo.",
    ["Got a stranger by {town}. Easy, nobody's shooting."] = "Tenemos a un desconocido por {town}. Tranquilos, nadie dispara.",
    ["Standoff by {town}. Nobody move yet."] = "Enfrentamiento por {town}. Nadie se mueva todavía.",
    ["Holding. They haven't backed off."] = "Aguantando. No han retrocedido.",
    ["Got a fire going."] = "Ya prendí una fogata.",
    ["Warming up a minute."] = "Calentándome un minuto.",
    ["Anybody heard from {who}?"] = "¿Alguien sabe algo de {who}?",
    ["{who} isn't answering."] = "{who} no contesta.",
    ["{who}, check in."] = "{who}, repórtate.",
    ["Still nothing from {who}."] = "Nada todavía de {who}.",
    ["Everybody in. We go for the place near {town} tonight."] = "Todos adentro. Esta noche vamos por el lugar cerca de {town}.",
    ["Tonight. The place by {town}. Bring everything."] = "Esta noche. El lugar por {town}. Traigan todo.",
    ["We hit {town} after dark. Be at the house by then."] = "Caemos sobre {town} al anochecer. Estén en la casa para entonces.",
    ["Whoever has {owner}'s phone, we know."] = "Quien tenga el teléfono de {owner}: lo sabemos.",
    ["{owner}'s phone is still on. Funny, that."] = "El teléfono de {owner} sigue encendido. Qué curioso.",

    -- Numbers that answer with a recording (Core/Recordings) ---------------------------------------------------
    ["Spiffo's"] = "Spiffo's",
    ["Muldraugh Hardware"] = "Ferretería Muldraugh",
    ["the Muldraugh pharmacy"] = "la farmacia de Muldraugh",
    ["First Baptist Church of Muldraugh"] = "Primera Iglesia Bautista de Muldraugh",
    ["the Meade County Sheriff, Muldraugh office"] = "la oficina del sheriff del condado de Meade en Muldraugh",
    ["West Point Hardware"] = "Ferretería West Point",
    ["Spiffo's West Point"] = "Spiffo's West Point",
    ["West Point Elementary"] = "Primaria West Point",
    ["the Riverside pharmacy"] = "la farmacia de Riverside",
    ["Riverside Methodist Church"] = "Iglesia Metodista de Riverside",
    ["the Riverside Gas-2-Go"] = "el Gas-2-Go de Riverside",
    ["the Rosewood Sheriff's station"] = "la estación del sheriff de Rosewood",
    ["Rosewood Elementary"] = "Primaria Rosewood",
    ["Rosewood Hardware and Feed"] = "Ferretería y Forrajes Rosewood",
    ["March Ridge Community Church"] = "Iglesia Comunitaria de March Ridge",
    ["the March Ridge Fossoil"] = "el Fossoil de March Ridge",
    ["Thanks for calling {name} in {town}! / We're open ten to ten, seven days a week. / Leave a message and we'll call you right back."] =
        "¡Gracias por llamar a {name} en {town}! / Abrimos de diez a diez, los siete días de la semana. / Deje un mensaje y le devolvemos la llamada.",
    ["You've reached {name}. / Our hours are nine to seven. For a refill, leave your name and prescription number after the tone."] =
        "Se comunicó con {name}. / Nuestro horario es de nueve a siete. Para resurtir una receta, deje su nombre y número de receta después del tono.",
    ["Thank you for calling {name}. / Sunday service is at ten. / Leave a message and the pastor will call you back."] =
        "Gracias por llamar a {name}. / El servicio del domingo es a las diez. / Deje un mensaje y el pastor le devolverá la llamada.",
    ["You've reached {name}. / If this is an emergency, hang up and dial nine-one-one. / Otherwise leave a message."] =
        "Se comunicó con {name}. / Si es una emergencia, cuelgue y marque nueve-uno-uno. / Si no, deje un mensaje.",
    ["You've reached {name}. / School is out for the summer. The office is open Tuesdays and Thursdays."] =
        "Se comunicó con {name}. / La escuela está de vacaciones de verano. La oficina abre martes y jueves.",
    ["{name}. We're open eight to six, closed Sundays. / Leave a message."] =
        "{name}. Abrimos de ocho a seis, cerramos los domingos. / Deje un mensaje.",
    ["{name}. We're open twenty-four hours. / Leave a message for the manager."] =
        "{name}. Abrimos las veinticuatro horas. / Deje un mensaje para el gerente.",
    ["You've reached {name}. / Because of the emergency we are closed until further notice. / Please don't come by. Stay safe."] =
        "Se comunicó con {name}. / Por la emergencia estamos cerrados hasta nuevo aviso. / Por favor no venga. Cuídese.",
    ["This is {name}. / We are out of antibiotics and fever reducers. / If you are sick, do not come to the pharmacy. Stay home."] =
        "Habla {name}. / Ya no tenemos antibióticos ni medicinas para la fiebre. / Si está enfermo, no venga a la farmacia. Quédese en casa.",
    ["This is {name}. / The fellowship hall is open to anyone who needs somewhere to go. / Come to the side door and knock. We'll let you in."] =
        "Habla {name}. / El salón comunitario está abierto para quien no tenga adónde ir. / Toque en la puerta lateral. Le abriremos.",
    ["You've reached {name}. / Deputies cannot respond to calls that are not emergencies. / Stay inside and keep your doors locked."] =
        "Se comunicó con {name}. / Los alguaciles no pueden atender llamadas que no sean emergencias. / Quédese adentro y con las puertas cerradas con llave.",
    ["This is {name}. / The building is being used by the county. / Please do not come to the school. Please."] =
        "Habla {name}. / El condado está usando el edificio. / Por favor no venga a la escuela. Por favor.",
    ["{name}. / We're out of plywood, nails and generators. / We're closing early until this is over."] =
        "{name}. / Se nos acabaron el contrachapado, los clavos y los generadores. / Cerramos temprano hasta que esto pase.",
    ["{name}. / No gas until the truck comes. We don't know when the truck comes."] =
        "{name}. / No hay gasolina hasta que llegue el camión. No sabemos cuándo llega el camión.",
    ["Nine-one-one, please hold. / All of our dispatchers are on other calls. / Please stay on the line. Do not hang up."] =
        "Nueve-uno-uno, por favor espere. / Todos nuestros operadores están atendiendo otras llamadas. / Por favor no se retire. No cuelgue.",
    ["You have reached Knox County Emergency Communications. / Because of the number of calls, units cannot be sent to every address. / Stay inside. Lock your doors. Do not go near anyone who is sick."] =
        "Se comunicó con Comunicaciones de Emergencia del Condado de Knox. / Por la cantidad de llamadas, no se pueden enviar unidades a todos los domicilios. / Quédese adentro. Cierre sus puertas con llave. No se acerque a nadie que esté enfermo.",
    ["This is a recorded message from the Kentucky Division of Emergency Management. / Emergency services in the Knox County area are suspended. / Shelter in place. Listen to the Emergency Broadcast System for instructions."] =
        "Este es un mensaje grabado de la División de Manejo de Emergencias de Kentucky. / Los servicios de emergencia en el área del condado de Knox están suspendidos. / Resguárdese donde está. Escuche el Sistema de Transmisión de Emergencia para recibir instrucciones.",
    ["Thank you for calling the Kentucky public information line. / If someone in your home has a fever or has been bitten, keep them in a separate room. / Do not travel. Checkpoints are in place on 31W and the interstate."] =
        "Gracias por llamar a la línea de información pública de Kentucky. / Si alguien en su casa tiene fiebre o fue mordido, manténgalo en un cuarto aparte. / No viaje. Hay retenes en la 31W y en la interestatal.",
    ["This is the Kentucky public information line. / The Knox County exclusion zone is closed. No one will be allowed to leave. / Do not approach the fence. This message will be updated."] =
        "Esta es la línea de información pública de Kentucky. / La zona de exclusión del condado de Knox está cerrada. No se permitirá salir a nadie. / No se acerque a la cerca. Este mensaje se actualizará.",
    ["Kentucky info line"] = "Línea de información de Kentucky",
    ["Directory assistance is not available at this time. / Please try your call again later."] =
        "El servicio de información no está disponible en este momento. / Por favor intente su llamada más tarde.",
    ["Directory assistance. What city, please?"] = "Información. ¿Qué ciudad, por favor?",
    ["{town}. One moment."] = "{town}. Un momento.",
    ["The state information line is {number}."] = "La línea de información del estado es el {number}.",
    ["The mailbox you have reached is full."] = "El buzón al que llamó está lleno.",

    -- PIN clues (Core/Clues): %1 the code, %2 the owner's first name -------------------------------------------
    ["phone %1"] = "teléfono %1",
    ["new phone code: %1"] = "código nuevo del teléfono: %1",
    ["PIN %1 - don't lose this one"] = "PIN %1 - no lo pierdas",
    ["cell %1 (NOT the bank card)"] = "celular %1 (NO es el de la tarjeta del banco)",
    ["code for the phone is %1, same as the garage"] = "el código del teléfono es %1, igual que el del garaje",
    ["%1 phone. remember it this time"] = "%1 teléfono. acuérdate esta vez",
    ["phone code = my birthday (month, day)"] = "código del teléfono = mi cumpleaños (mes, día)",
    ["PIN is my bday. month then day"] = "el PIN es mi cumple. mes y luego día",
    ["%2 - your new phone code is %1. Write it somewhere that ISN'T the fridge."] =
        "%2 - tu código nuevo del teléfono es %1. Anótalo en algún lugar que NO sea el refri.",
    ["%2's cell: %1"] = "celular de %2: %1",
    ["phone PIN %1 (don't tell your brother)"] = "PIN del teléfono %1 (no le digas a tu hermano)",
    ["%2, the code for the phone is %1. Love you."] = "%2, el código del teléfono es %1. Te quiero.",
    ["cell code %1 - same as the alarm"] = "código del celular %1 - igual que la alarma",
    ["new phone - %1"] = "teléfono nuevo - %1",
    ["cell PIN %1 - leave this in the glove box"] = "PIN del celular %1 - deja esto en la guantera",
    ["%2's phone code %1"] = "código del teléfono de %2: %1",
    ["A strip of masking tape on the back, in marker: %1"] = "Una tira de cinta adhesiva atrás, escrita con marcador: %1",
    ["Scratched into the battery cover: %1"] = "Rayado en la tapa de la batería: %1",
    ["A label on the back: PIN %1"] = "Una etiqueta atrás: PIN %1",
    ["Written on the back in nail polish: %1"] = "Escrito atrás con esmalte de uñas: %1",
    ["Hon"] = "Cariño",
}
