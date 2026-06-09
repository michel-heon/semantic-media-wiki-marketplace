#!/usr/bin/env python3
"""
populate-wiki.py — Population du wiki SMW avec contenu bilingue démo marketplace

Thèmes: Intelligence artificielle, Souveraineté numérique, Québec
Contenu: Bilingue (français/anglais) avec annotations SMW sémantiques
Source: Contenu rédigé + références DBpedia

Usage:
  python3 populate-wiki.py [--wiki-url URL] [--user USER] [--password PASS]

Exemples:
  python3 populate-wiki.py
  python3 populate-wiki.py --wiki-url https://smw-dev-20260519.canadacentral.cloudapp.azure.com
  python3 populate-wiki.py --wiki-url https://20.151.0.200 --user WikiAdmin --password WikiAdmin2026
"""

import sys
import json
import argparse
import urllib.request
import urllib.parse
import http.cookiejar
import ssl
import time

DEFAULT_WIKI = "https://smw-dev-20260519.canadacentral.cloudapp.azure.com"
DEFAULT_USER = "WikiAdmin"
DEFAULT_PASS = "WikiAdmin2026"

# ============================================================
# SMW PROPERTIES
# ============================================================
PROPERTIES = {
    "Property:Domaine": """\
This property is of type [[Has type::Text]].

Domaine thématique principal de l'article / Main thematic domain of the article.

Valeurs typiques / Typical values: ''Intelligence artificielle'', ''Souveraineté numérique'', ''Québec'', ''Technologie''

[[Category:SMW Properties]]
""",
    "Property:Langue": """\
This property is of type [[Has type::Text]].

Langue principale de l'article / Main language of the article.

Valeurs / Values: <code>fr</code> (français), <code>en</code> (English), <code>fr-en</code> (bilingue)

[[Category:SMW Properties]]
""",
    "Property:Titre anglais": """\
This property is of type [[Has type::Text]].

Titre anglais de la page / English title of the page.

[[Category:SMW Properties]]
""",
    "Property:Est lié à": """\
This property is of type [[Has type::Page]].

Relation sémantique vers des concepts liés / Semantic relation to related concepts.

[[Category:SMW Properties]]
""",
    "Property:Source DBpedia": """\
This property is of type [[Has type::URL]].

Lien vers la ressource DBpedia correspondante / Link to the corresponding DBpedia resource.

[[Category:SMW Properties]]
""",
    "Property:Année introduction": """\
This property is of type [[Has type::Number]].

Année d'introduction ou de création du concept / Year of introduction or creation of the concept.

[[Category:SMW Properties]]
""",
    "Property:Organisation clé": """\
This property is of type [[Has type::Text]].

Organisation ou institution clé associée au concept / Key organization or institution associated with the concept.

[[Category:SMW Properties]]
""",
}

# ============================================================
# TEMPLATES
# ============================================================
TEMPLATES = {
    "Template:Infobox concept numérique": """\
<noinclude>
== Infobox concept numérique ==

Ce modèle crée une boîte d'information bilingue pour les concepts numériques avec annotations SMW.

=== Utilisation ===
<pre>
{{Infobox concept numérique
|titre_fr     = Titre en français
|titre_en     = English title
|domaine      = Domaine (ex: Intelligence artificielle)
|langue       = fr-en
|année        = 2000
|organisation = Organisation clé
|description_fr = Description courte en français
|description_en = Short description in English
|source       = https://dbpedia.org/resource/...
}}
</pre>
[[Category:Templates]]
</noinclude><includeonly>{{#set: domaine={{{domaine|}}} | langue={{{langue|fr-en}}} | Titre anglais={{{titre_en|}}} | Année introduction={{{année|}}} | Organisation clé={{{organisation|}}} }}{| class="wikitable" style="float:right; margin:0 0 1.2em 1.5em; width:320px; border:2px solid #1565c0;"
|-
! colspan="2" style="background:#1565c0; color:white; font-size:1.1em; padding:8px;" | {{{titre_fr|Concept}}}
|-
| colspan="2" style="font-style:italic; color:#555; padding:6px;" | ''EN: {{{titre_en|}}}''
|-
! style="background:#e3f2fd; width:40%;" | Domaine
| {{{domaine|}}}
|-
! style="background:#e3f2fd;" | Langue
| {{{langue|fr-en}}}
{{#if:{{{année|}}}|{{!}}-
! style="background:#e3f2fd;" {{!}} Introduit en
{{!}} {{{année|}}}}}
{{#if:{{{organisation|}}}|{{!}}-
! style="background:#e3f2fd;" {{!}} Organisation
{{!}} {{{organisation|}}}}}
{{#if:{{{description_fr|}}}|{{!}}-
{{!}} colspan="2" style="padding:8px;" {{!}} '''FR:''' {{{description_fr|}}}}}
{{#if:{{{description_en|}}}|{{!}}-
{{!}} colspan="2" style="padding:8px; font-style:italic;" {{!}} ''EN: {{{description_en|}}}''}}
{{#if:{{{source|}}}|{{!}}-
{{!}} colspan="2" style="text-align:center; padding:6px;" {{!}} [{{{source}}} DBpedia]}}
|}
</includeonly>
""",
}

# ============================================================
# CATEGORIES
# ============================================================
CATEGORIES = {
    "Category:SMW Properties": """\
Cette catégorie regroupe toutes les propriétés Semantic MediaWiki définies dans ce wiki.

''This category groups all Semantic MediaWiki properties defined in this wiki.''

Ces propriétés permettent d'annoter sémantiquement les articles et d'effectuer des requêtes structurées avec <code>{{#ask: ...}}</code>.

''These properties allow semantic annotation of articles and structured queries using <code>{{#ask: ...}}</code>.''
""",
    "Category:Templates": """\
Cette catégorie regroupe tous les modèles (templates) utilisés dans ce wiki.

''This category groups all templates used in this wiki.''
""",
    "Category:Concepts numériques": """\
La '''catégorie Concepts numériques''' est la catégorie racine du wiki SMW Marketplace. Elle regroupe l'ensemble des articles sur les technologies numériques, l'intelligence artificielle, la souveraineté des données et le numérique québécois.

''The '''Digital Concepts''' category is the root category of the SMW Marketplace wiki. It groups all articles on digital technologies, artificial intelligence, data sovereignty, and Quebec's digital ecosystem.''

{{#ask: [[Domaine::+]]
 | ?Domaine
 | ?Titre anglais
 | ?Langue
 | format=table
 | headers=show
 | mainlabel=Article
 | caption=Tous les articles sémantiques / All semantic articles
 | limit=50
 | sort=Domaine
}}
""",
    "Category:Intelligence artificielle": """\
La '''catégorie Intelligence artificielle''' regroupe tous les articles du wiki portant sur les technologies, concepts, outils et organisations liés à l'intelligence artificielle.

''The '''Artificial Intelligence''' category groups all wiki articles related to artificial intelligence technologies, concepts, tools, and organizations.''

{{#ask: [[Domaine::Intelligence artificielle]]
 | ?Titre anglais
 | ?Langue
 | ?Année introduction
 | format=table
 | headers=show
 | caption=Articles sur l'IA / AI articles
 | limit=20
}}

[[Category:Concepts numériques]]
""",
    "Category:Souveraineté numérique": """\
La '''catégorie Souveraineté numérique''' regroupe les articles traitant du contrôle des données, de la gouvernance numérique, de la vie privée et de l'infrastructure technologique souveraine.

''The '''Digital Sovereignty''' category covers articles on data control, digital governance, privacy, and sovereign technological infrastructure.''

{{#ask: [[Domaine::Souveraineté numérique]]
 | ?Titre anglais
 | ?Langue
 | ?Organisation clé
 | format=table
 | headers=show
 | caption=Articles sur la souveraineté numérique
 | limit=20
}}

[[Category:Concepts numériques]]
""",
    "Category:Québec": """\
La '''catégorie Québec''' regroupe les articles portant sur le Québec, sa langue, sa culture, son économie numérique et son rôle dans l'écosystème de l'intelligence artificielle mondial.

''The '''Quebec''' category groups articles about Quebec, its language, culture, digital economy, and role in the global artificial intelligence ecosystem.''

{{#ask: [[Domaine::Québec]]
 | ?Titre anglais
 | ?Langue
 | ?Organisation clé
 | format=table
 | headers=show
 | caption=Articles sur le Québec
 | limit=20
}}

[[Category:Concepts numériques]]
""",
}

# ============================================================
# CONTENT PAGES
# ============================================================
PAGES = {

    # ---- INTELLIGENCE ARTIFICIELLE ----

    "Intelligence artificielle": """\
{{Infobox concept numérique
|titre_fr     = Intelligence artificielle
|titre_en     = Artificial intelligence
|domaine      = Intelligence artificielle
|langue       = fr-en
|année        = 1956
|organisation = OpenAI, DeepMind, Mila
|description_fr = Simulation de processus cognitifs humains par des machines
|description_en = Simulation of human cognitive processes by machines
|source       = https://dbpedia.org/resource/Artificial_intelligence
}}

== Définition / Definition ==

L''''intelligence artificielle''' (IA) désigne l'ensemble des théories et techniques développées pour permettre à des machines de simuler certains aspects de l'intelligence humaine, notamment la capacité d'apprendre, de raisonner, de résoudre des problèmes et de comprendre le langage naturel.

''Artificial intelligence (AI) refers to the simulation of human intelligence in machines that are programmed to think and learn like humans. The term may also apply to any machine that exhibits traits associated with a human mind such as learning and problem-solving.''

== Histoire / History ==

Le terme "intelligence artificielle" a été introduit en '''1956''' lors d'une conférence à Dartmouth College par [[John McCarthy]], [[Marvin Minsky]], [[Claude Shannon]] et [[Nathaniel Rochester]]. Depuis lors, le domaine a connu plusieurs cycles d'enthousiasme et de désillusion, souvent appelés "hivers de l'IA".

''The term "artificial intelligence" was coined in 1956 at the Dartmouth Conference by John McCarthy, Marvin Minsky, Claude Shannon, and Nathaniel Rochester. Since then, the field has experienced cycles of enthusiasm and disillusionment, often called "AI winters."''

== Sous-domaines / Subfields ==

=== Apprentissage automatique / Machine learning ===

Voir / See: [[Apprentissage automatique]]

L'[[apprentissage automatique]] permet aux systèmes d'apprendre et de s'améliorer à partir de l'expérience sans être explicitement programmés.

=== Traitement du langage naturel / Natural Language Processing ===

Le traitement du langage naturel (TLN / NLP) permet aux machines de comprendre, d'interpréter et de générer le langage humain. C'est la base des assistants vocaux et des [[Grands modèles de langage]].

=== Vision par ordinateur / Computer Vision ===

Capacité des machines à interpréter et comprendre les informations visuelles du monde réel.

=== IA générative / Generative AI ===

Voir / See: [[IA générative]]

== IA au Québec / AI in Quebec ==

Le Québec est devenu un centre mondial d'excellence en intelligence artificielle, notamment grâce au [[Mila - Institut québécois d'intelligence artificielle]] fondé par [[Yoshua Bengio]], lauréat du Prix Turing 2018.

''Quebec has become a global center of excellence in artificial intelligence, notably through the Mila — Quebec AI Institute founded by Yoshua Bengio, 2018 Turing Award laureate.''

== Enjeux éthiques / Ethical challenges ==

* Biais algorithmiques / Algorithmic bias
* Vie privée et [[Protection des données personnelles]]
* [[Souveraineté numérique]] des données d'entraînement
* Transparence et explicabilité des modèles
* Impact sur l'emploi / Impact on employment

== Références ==

* DBpedia: [https://dbpedia.org/resource/Artificial_intelligence Artificial intelligence]
* [https://www.mila.quebec Mila — Institut québécois d'IA]
* [https://ivado.ca IVADO — Institut de valorisation des données]

[[Category:Intelligence artificielle]]
[[Category:Concepts numériques]]
""",

    "Apprentissage automatique": """\
{{Infobox concept numérique
|titre_fr     = Apprentissage automatique
|titre_en     = Machine learning
|domaine      = Intelligence artificielle
|langue       = fr-en
|année        = 1959
|organisation = Google DeepMind, OpenAI, Mila
|description_fr = Branche de l'IA permettant aux systèmes d'apprendre de l'expérience
|description_en = Branch of AI enabling systems to learn from experience
|source       = https://dbpedia.org/resource/Machine_learning
}}

== Définition ==

L''''apprentissage automatique''' (ou ''machine learning'' en anglais) est une sous-discipline de l'[[intelligence artificielle]] qui donne aux ordinateurs la capacité d'apprendre à partir de données sans être explicitement programmés pour chaque tâche.

''Machine learning (ML) is a branch of artificial intelligence and computer science which focuses on the use of data and algorithms to imitate the way that humans learn, gradually improving its accuracy.''

== Types d'apprentissage / Types of learning ==

=== Apprentissage supervisé / Supervised learning ===

Le modèle est entraîné sur des données étiquetées. Exemples: classification d'images, détection de spam, prédiction de prix.

''The model is trained on labeled data. Examples: image classification, spam detection, price prediction.''

=== Apprentissage non supervisé / Unsupervised learning ===

Le modèle découvre des patterns dans des données non étiquetées. Exemples: clustering, réduction de dimensionnalité.

=== Apprentissage par renforcement / Reinforcement learning ===

Un agent apprend en interagissant avec un environnement et en recevant des récompenses ou des pénalités.

== Applications ==

* Reconnaissance vocale / Speech recognition
* Traduction automatique / Machine translation
* Recommandation de contenu / Content recommendation
* Diagnostic médical / Medical diagnosis
* Conduite autonome / Autonomous driving
* Détection de fraude / Fraud detection

== Au Québec ==

Le [[Mila - Institut québécois d'intelligence artificielle]] est l'un des centres de recherche en apprentissage automatique les plus importants au monde, avec plus de 1000 chercheurs et étudiants. [[Yoshua Bengio]], pionnier du ''deep learning'', y a développé des travaux fondateurs sur les réseaux de neurones profonds.

== Références ==

* DBpedia: [https://dbpedia.org/resource/Machine_learning Machine learning]
* [https://www.mila.quebec Mila]

[[Category:Intelligence artificielle]]
[[Category:Concepts numériques]]
""",

    "Grands modèles de langage": """\
{{Infobox concept numérique
|titre_fr     = Grands modèles de langage
|titre_en     = Large language models
|domaine      = Intelligence artificielle
|langue       = fr-en
|année        = 2017
|organisation = OpenAI, Google, Meta, Mila
|description_fr = Modèles d'IA entraînés sur de vastes corpus de texte
|description_en = AI models trained on vast text corpora
|source       = https://dbpedia.org/resource/Large_language_model
}}

== Définition ==

Les '''grands modèles de langage''' (GML), ou ''Large Language Models'' (LLM) en anglais, sont des modèles d'[[intelligence artificielle]] basés sur des architectures de transformeurs (''transformers''), entraînés sur des volumes massifs de texte pour comprendre et générer du langage naturel.

''Large language models (LLMs) are a type of AI algorithm that uses deep learning techniques and massively large data sets to understand, summarize, generate, and predict new content.''

== Modèles phares / Key models ==

{| class="wikitable"
! Modèle / Model !! Organisation !! Année
|-
| GPT-4 || OpenAI || 2023
|-
| Gemini Ultra || Google DeepMind || 2024
|-
| LLaMA 3 || Meta AI || 2024
|-
| Claude 3.5 Sonnet || Anthropic || 2024
|-
| Mistral Large || Mistral AI || 2024
|}

== Architecture Transformer ==

L'architecture ''Transformer'', introduite en 2017 dans l'article "Attention is All You Need", est la base de tous les GML modernes. Elle repose sur le mécanisme d''''attention''' qui permet au modèle de considérer le contexte global d'une séquence de texte.

== Enjeux / Challenges ==

=== Souveraineté des données ===

La [[souveraineté numérique]] est un enjeu majeur : les données d'entraînement de nombreux GML proviennent de sources internationales, soulevant des questions sur la représentation des langues minoritaires comme le français québécois.

=== Biais et hallucinations ===

Les GML peuvent générer des informations incorrectes ("hallucinations") ou refléter des biais présents dans leurs données d'entraînement.

== Initiatives québécoises ==

[[Yoshua Bengio]] du [[Mila - Institut québécois d'intelligence artificielle]] a été un pionnier du ''deep learning'' qui a rendu possible les GML modernes. Le Québec travaille au développement de modèles adaptés au français québécois.

== Références ==

* DBpedia: [https://dbpedia.org/resource/Large_language_model Large language model]
* [https://www.mila.quebec Mila]

[[Category:Intelligence artificielle]]
[[Category:Concepts numériques]]
""",

    "IA générative": """\
{{Infobox concept numérique
|titre_fr     = IA générative
|titre_en     = Generative AI
|domaine      = Intelligence artificielle
|langue       = fr-en
|année        = 2014
|organisation = OpenAI, Google DeepMind, Stability AI
|description_fr = IA capable de créer du nouveau contenu (texte, images, code, audio)
|description_en = AI capable of creating new content (text, images, code, audio)
|source       = https://dbpedia.org/resource/Generative_artificial_intelligence
}}

== Définition ==

L''''IA générative''' désigne les systèmes d'[[intelligence artificielle]] capables de créer du nouveau contenu — texte, images, vidéo, audio, code — à partir de données d'entraînement. Contrairement aux systèmes d'IA discriminants qui classifient les données existantes, les systèmes génératifs '''créent''' de nouveaux artefacts.

''Generative AI refers to artificial intelligence systems that can generate new content — text, images, video, audio, code — based on patterns learned from training data.''

== Technologies clés / Key technologies ==

=== GANs (Generative Adversarial Networks) ===

Introduits en 2014, les GAN mettent en compétition un '''générateur''' et un '''discriminateur'''. Utilisés principalement pour la génération d'images réalistes.

=== Transformers et LLM ===

Voir [[Grands modèles de langage]] — la base de ChatGPT, Gemini, Claude, Copilot, etc.

=== Modèles de diffusion / Diffusion models ===

Stable Diffusion, DALL-E 3, Midjourney — génération d'images haute qualité à partir de texte.

== Applications par domaine ==

{| class="wikitable"
! Domaine !! Outils !! Usage
|-
| Texte / Text || ChatGPT, Claude, Gemini || Rédaction, résumé, traduction
|-
| Code / Code || GitHub Copilot, CodeLlama || Génération et complétion de code
|-
| Images / Images || DALL-E 3, Midjourney || Création visuelle, design
|-
| Audio / Audio || ElevenLabs, Suno || Synthèse vocale, musique
|-
| Vidéo / Video || Sora, Runway || Génération de vidéo
|}

== Impacts socio-économiques ==

L'IA générative transforme profondément le marché du travail, la création artistique, l'éducation et la [[souveraineté numérique]]. Le gouvernement du Québec a adopté une stratégie pour encadrer et encourager son développement responsable.

== Références ==

* DBpedia: [https://dbpedia.org/resource/Generative_artificial_intelligence Generative AI]
* [https://openai.com OpenAI]

[[Category:Intelligence artificielle]]
[[Category:Concepts numériques]]
""",

    # ---- SOUVERAINETÉ NUMÉRIQUE ----

    "Souveraineté numérique": """\
{{Infobox concept numérique
|titre_fr     = Souveraineté numérique
|titre_en     = Digital sovereignty
|domaine      = Souveraineté numérique
|langue       = fr-en
|année        = 2014
|organisation = Union européenne, Gouvernement du Québec, ANSSI
|description_fr = Capacité d'un État à contrôler ses infrastructures et données numériques
|description_en = A state's ability to control its digital infrastructure and data
|source       = https://dbpedia.org/resource/Digital_sovereignty
}}

== Définition ==

La '''souveraineté numérique''' désigne la capacité d'un État, d'une organisation ou d'un individu à exercer un contrôle effectif sur ses infrastructures numériques, ses données et ses algorithmes, indépendamment de dépendances technologiques externes.

''Digital sovereignty refers to the ability of a state, organization, or individual to exercise effective control over its digital infrastructure, data, and algorithms, independent of external technological dependencies.''

== Dimensions ==

=== Souveraineté des données / Data sovereignty ===

Contrôle sur la collecte, le stockage, le traitement et le partage des données personnelles et institutionnelles. Au Québec, encadrée par la '''Loi 25''' (Loi modernisant des dispositions législatives en matière de protection des renseignements personnels).

=== Souveraineté des infrastructures / Infrastructure sovereignty ===

Contrôle sur les serveurs, réseaux et [[cloud souverain|clouds souverains]] utilisés pour traiter les données nationales.

=== Souveraineté algorithmique / Algorithmic sovereignty ===

Capacité à auditer, comprendre et contrôler les algorithmes — notamment les systèmes d'[[intelligence artificielle]] — qui influencent les décisions publiques et privées.

=== Souveraineté industrielle / Industrial sovereignty ===

Capacité à développer localement des technologies numériques clés, notamment en [[intelligence artificielle]].

== Cadres réglementaires / Regulatory frameworks ==

=== Union européenne ===

* [[RGPD]] (Règlement Général sur la Protection des Données) — 2018
* AI Act — 2024 (premier règlement mondial sur l'IA)
* GAIA-X — Initiative de [[cloud souverain]] européen

=== Québec et Canada ===

* '''Loi 25''' — Loi modernisant la protection des renseignements personnels (2021-2023)
* '''Directive sur les services infonuagiques''' du gouvernement du Québec
* '''Stratégie québécoise de l'intelligence artificielle'''

== Enjeux pour le Québec ==

Le Québec fait face à un paradoxe : c'est un écosystème d'IA mondialement reconnu (grâce à [[Mila - Institut québécois d'intelligence artificielle|Mila]], [[Scale AI (Québec)|Scale AI]]), mais dépendant d'infrastructures cloud américaines (AWS, Azure, Google Cloud). La souveraineté numérique impose de développer des [[cloud souverain|alternatives souveraines]].

''Quebec faces a paradox: it is a globally recognized AI ecosystem, but dependent on American cloud infrastructure. Digital sovereignty demands developing sovereign alternatives.''

== SMW Marketplace et la souveraineté ==

Ce wiki démonstratif illustre comment une solution open-source comme [[Semantic MediaWiki]] peut être déployée sur [[cloud souverain|Azure Canada Central]] pour répondre aux exigences de résidence des données québécoises.

== Références ==

* DBpedia: [https://dbpedia.org/resource/Digital_sovereignty Digital sovereignty]
* [https://www.legisquebec.gouv.qc.ca Loi 25 — LegisQuébec]

[[Category:Souveraineté numérique]]
[[Category:Concepts numériques]]
""",

    "RGPD": """\
{{Infobox concept numérique
|titre_fr     = RGPD — Règlement Général sur la Protection des Données
|titre_en     = GDPR — General Data Protection Regulation
|domaine      = Souveraineté numérique
|langue       = fr-en
|année        = 2018
|organisation = Union européenne
|description_fr = Règlement européen encadrant la protection des données personnelles
|description_en = European regulation governing personal data protection
|source       = https://dbpedia.org/resource/General_Data_Protection_Regulation
}}

== Présentation / Overview ==

Le '''Règlement Général sur la Protection des Données''' (RGPD, ou GDPR en anglais) est un règlement de l'[[Union européenne]] qui encadre le traitement des données personnelles dans l'UE et l'Espace économique européen (EEE). Entré en vigueur le '''25 mai 2018''', il est considéré comme la réglementation de protection des données la plus stricte au monde.

''The General Data Protection Regulation (GDPR) is a regulation in EU law on data protection and privacy in the European Union. It came into effect on May 25, 2018, and is widely considered the world's strongest set of data protection rules.''

== Principes fondamentaux / Core principles ==

# '''Licéité, loyauté et transparence''' / Lawfulness, fairness and transparency
# '''Limitation des finalités''' / Purpose limitation
# '''Minimisation des données''' / Data minimisation
# '''Exactitude''' / Accuracy
# '''Limitation de la conservation''' / Storage limitation
# '''Intégrité et confidentialité''' / Integrity and confidentiality
# '''Responsabilité''' / Accountability

== Droits des individus / Individual rights ==

* Droit d'accès / Right of access
* Droit à la rectification / Right to rectification
* Droit à l'effacement ("droit à l'oubli") / Right to erasure
* Droit à la portabilité / Right to data portability
* Droit d'opposition / Right to object

== Influence internationale ==

Le RGPD a inspiré de nombreuses législations mondiales :

* '''Loi 25''' au Québec (2021-2023)
* CCPA en Californie (2020)
* LGPD au Brésil (2020)
* PDPA en Thaïlande (2022)

== Lien avec la [[Souveraineté numérique]] ==

Le RGPD est un instrument fondamental de [[souveraineté numérique]] en ce qu'il impose des contraintes aux transferts de données hors de l'UE et oblige les entreprises à justifier leurs traitements de données.

== Références ==

* DBpedia: [https://dbpedia.org/resource/General_Data_Protection_Regulation GDPR]
* [https://gdpr.eu GDPR.eu]

[[Category:Souveraineté numérique]]
[[Category:Concepts numériques]]
""",

    "Cloud souverain": """\
{{Infobox concept numérique
|titre_fr     = Cloud souverain
|titre_en     = Sovereign cloud
|domaine      = Souveraineté numérique
|langue       = fr-en
|année        = 2020
|organisation = GAIA-X, OVHcloud, Microsoft Azure
|description_fr = Infrastructure cloud sous contrôle national ou régional
|description_en = Cloud infrastructure under national or regional control
|source       = https://dbpedia.org/resource/Sovereign_cloud
}}

== Définition ==

Un '''cloud souverain''' est une infrastructure d'informatique en nuage (''cloud computing'') qui garantit que les données sont stockées et traitées dans une juridiction spécifique, sous le contrôle de lois nationales ou régionales, et sans ingérence étrangère.

''A sovereign cloud is a cloud computing infrastructure that ensures data is stored and processed within a specific jurisdiction, under national or regional law, and free from foreign interference.''

== Initiatives majeures ==

=== GAIA-X (Europe) ===

Initiative franco-allemande lancée en 2020 pour créer un écosystème de données européen interopérable et souverain. Regroupe plus de 300 organisations de 30 pays.

=== Gouvernement du Québec ===

La '''Directive sur les services infonuagiques''' du gouvernement du Québec exige que les données sensibles soient hébergées au Québec ou au Canada. Cela favorise :

* OVHcloud (centres de données à Montréal et Beauharnois)
* IBM Cloud (centres au Canada)
* Nuage gouvernemental fédéral (GC)

=== Azure Canada ===

Microsoft Azure dispose de centres de données '''Canada Central''' (Toronto) et '''Canada East''' (Québec City), permettant de respecter les exigences de résidence des données canadiennes et québécoises.

== SMW Marketplace et le cloud souverain ==

Ce wiki démonstratif est hébergé sur '''Azure Canada Central''', démontrant qu'une solution de gestion des connaissances open-source comme [[Semantic MediaWiki]] peut être déployée dans un cloud souverain conforme aux exigences québécoises et canadiennes.

''This demonstration wiki is hosted on Azure Canada Central, showing that an open-source knowledge management solution like Semantic MediaWiki can be deployed in a sovereign cloud compliant with Quebec and Canadian data requirements.''

== Références ==

* DBpedia: [https://dbpedia.org/resource/Sovereign_cloud Sovereign cloud]
* [https://www.gaia-x.eu GAIA-X]

[[Category:Souveraineté numérique]]
[[Category:Concepts numériques]]
""",

    "Protection des données personnelles": """\
{{Infobox concept numérique
|titre_fr     = Protection des données personnelles
|titre_en     = Personal data protection
|domaine      = Souveraineté numérique
|langue       = fr-en
|année        = 1970
|organisation = CNIL (France), CAI (Québec), EDPB (UE)
|description_fr = Ensemble de mesures protégeant la vie privée dans le contexte numérique
|description_en = Set of measures protecting privacy in the digital context
|source       = https://dbpedia.org/resource/Information_privacy
}}

== Définition ==

La '''protection des données personnelles''' regroupe l'ensemble des principes, lois, techniques et pratiques visant à protéger les informations personnelles identifiables contre une collecte, un stockage, un traitement ou une divulgation non autorisés.

''Personal data protection encompasses all principles, laws, techniques, and practices aimed at protecting personally identifiable information (PII) from unauthorized collection, storage, processing, or disclosure.''

== Cadres au Québec / Quebec frameworks ==

=== Loi 25 (Québec) ===

La '''Loi 25''' (Loi modernisant des dispositions législatives en matière de protection des renseignements personnels) est la principale loi québécoise sur la protection des données. Adoptée en 2021 et déployée progressivement jusqu'en 2023, elle :

* Impose la désignation d'un responsable de la protection de la vie privée
* Exige des évaluations d'impact sur la vie privée (EFVP)
* Renforce les droits des individus (accès, rectification, portabilité)
* Aligne le Québec sur les standards du [[RGPD]] européen

=== Commission d'accès à l'information (CAI) ===

Organisme québécois chargé de surveiller l'application de la Loi 25 et de la Loi sur l'accès aux documents des organismes publics.

== Lien avec l'[[Intelligence artificielle]] ==

Les systèmes d'[[IA générative]] et d'[[apprentissage automatique]] soulèvent des enjeux complexes de protection des données :

* Données d'entraînement : droits d'auteur et données personnelles
* Inférences sur les individus à partir de modèles entraînés
* Droit à l'oubli difficile à implémenter dans les grands modèles de langage
* Transparence des systèmes automatisés de décision

== Références ==

* DBpedia: [https://dbpedia.org/resource/Information_privacy Information privacy]
* [https://www.cai.gouv.qc.ca CAI — Commission d'accès à l'information]

[[Category:Souveraineté numérique]]
[[Category:Concepts numériques]]
""",

    # ---- QUÉBEC ----

    "Québec (province)": """\
{{Infobox concept numérique
|titre_fr     = Québec (province)
|titre_en     = Quebec (province)
|domaine      = Québec
|langue       = fr-en
|année        = 1867
|organisation = Gouvernement du Québec
|description_fr = Province canadienne francophone, leader mondial en IA
|description_en = French-speaking Canadian province, global leader in AI
|source       = https://dbpedia.org/resource/Quebec
}}

== Présentation ==

Le '''Québec''' est une province du Canada dont la capitale est Québec (ville) et la métropole est Montréal. Avec une population de plus de 8,5 millions d'habitants, le Québec est la seule province majoritairement francophone du Canada et l'une des rares juridictions nord-américaines où le [[Langue française au Québec|français]] est la langue officielle.

''Quebec is a province of Canada with Quebec City as its capital and Montreal as its metropolis. With a population of over 8.5 million, Quebec is the only majority French-speaking province in Canada and one of the few North American jurisdictions where French is the official language.''

== Numérique et IA / Digital and AI ==

Le Québec s'est imposé comme un '''hub mondial de l'intelligence artificielle''', notamment grâce à :

=== Écosystème académique ===

* '''[[Mila - Institut québécois d'intelligence artificielle]]''' — fondé par Yoshua Bengio, plus de 1200 chercheurs
* '''IVADO''' — Institut de valorisation des données (UdeM, Polytechnique, HEC)
* '''CIFAR''' — Programme pan-canadien en IA
* Universités : Université de Montréal, Université Laval, McGill, UQAM, Concordia, Polytechnique, ÉTS

=== Écosystème industriel ===

* '''[[Scale AI (Québec)]]''' — Supergrappe d'innovation en IA
* Entreprises : BrainBox AI, Coveo, Moov.ai, Imagia Canexia Health
* Multinationales technologiques avec présence à Montréal : Microsoft, Google, Meta, Samsung, Ubisoft

=== Politique gouvernementale ===

* '''Stratégie québécoise de l'intelligence artificielle''' (SQIA) 2021-2026
* Plan d'action numérique du gouvernement
* Investissement Québec — programme IA

== Langue française et numérique ==

Le Québec défend activement la [[Langue française au Québec|langue française]] dans le numérique. Les enjeux incluent :

* Disponibilité des modèles d'IA en français québécois
* Francisation des interfaces technologiques
* Protection du français face aux [[Grands modèles de langage]] principalement anglophones

== Géographie numérique ==

=== Montréal ===

Centre névralgique de l'IA québécoise. Abrite [[Mila - Institut québécois d'intelligence artificielle|Mila]], [[Scale AI (Québec)|Scale AI]], et de nombreux laboratoires de R&D d'entreprises mondiales.

=== Beauharnois ===

Abrite l'un des plus grands centres de données d'Amérique du Nord (OVHcloud), alimenté à 99% d'énergie hydroélectrique renouvelable — un avantage pour un [[cloud souverain]] durable.

== Références ==

* DBpedia: [https://dbpedia.org/resource/Quebec Quebec]
* [https://www.quebec.ca Gouvernement du Québec]

[[Category:Québec]]
[[Category:Concepts numériques]]
""",

    "Mila - Institut québécois d'intelligence artificielle": """\
{{Infobox concept numérique
|titre_fr     = Mila — Institut québécois d'intelligence artificielle
|titre_en     = Mila — Quebec AI Institute
|domaine      = Québec
|langue       = fr-en
|année        = 1993
|organisation = Mila, Université de Montréal
|description_fr = Plus grand centre académique de recherche en apprentissage profond au monde
|description_en = World's largest academic deep learning research center
|source       = https://dbpedia.org/resource/Montreal_Institute_for_Learning_Algorithms
}}

== Présentation ==

Le '''Mila — Institut québécois d'intelligence artificielle''' est un centre de recherche en intelligence artificielle basé à Montréal, Québec. Fondé en '''1993''' par Yoshua Bengio sous le nom de "LISA" (Laboratoire d'Informatique des Systèmes Adaptatifs), il est devenu l'un des plus grands centres de recherche en [[apprentissage automatique|apprentissage profond]] au monde.

''Mila — Quebec AI Institute is an AI research center based in Montreal, Quebec. Founded in 1993 by Yoshua Bengio, it has grown to become one of the world's largest academic deep learning research centers.''

== Chiffres clés (2024) ==

{| class="wikitable"
! Indicateur !! Chiffre
|-
| Chercheurs principaux (faculty) || +150
|-
| Étudiants et post-doctorants || +1200
|-
| Publications annuelles || +500
|-
| Startups issues de Mila || +100
|-
| Partenaires industriels || +100
|}

== Yoshua Bengio — Fondateur ==

Yoshua Bengio est le fondateur et directeur scientifique de Mila. Professeur à l'Université de Montréal, il est l'un des pères du ''[[apprentissage automatique|deep learning]]'' moderne. En 2018, il a reçu le '''Prix Turing''' — souvent appelé le "Prix Nobel de l'informatique" — conjointement avec Geoffrey Hinton et Yann LeCun, pour leurs contributions fondamentales au deep learning.

== Domaines de recherche ==

* Apprentissage par renforcement / Reinforcement learning
* Traitement du langage naturel (TLN / NLP)
* Vision par ordinateur / Computer vision
* IA pour la santé / AI for health
* IA pour la lutte aux changements climatiques / AI for climate change
* Éthique de l'IA et [[souveraineté numérique]]

== Impact sur l'écosystème québécois ==

Mila a joué un rôle déterminant dans le positionnement du Québec comme hub mondial de l'IA. Les anciens élèves et chercheurs de Mila ont fondé ou rejoint des dizaines d'entreprises d'IA au Québec et dans le monde.

== Site web ==

[https://mila.quebec mila.quebec]

[[Category:Québec]]
[[Category:Intelligence artificielle]]
[[Category:Concepts numériques]]
""",

    "Scale AI (Québec)": """\
{{Infobox concept numérique
|titre_fr     = Scale AI — Supergrappe d'IA du Québec
|titre_en     = Scale AI — Quebec AI Supercluster
|domaine      = Québec
|langue       = fr-en
|année        = 2019
|organisation = Scale AI, Gouvernement du Canada, Gouvernement du Québec
|description_fr = Supergrappe d'innovation axée sur l'IA dans les chaînes d'approvisionnement
|description_en = AI-focused innovation supercluster for supply chain optimization
|source       = https://dbpedia.org/resource/Scale_AI
}}

== Présentation ==

'''Scale AI''' est l'une des cinq supergrappes d'innovation du Canada, lancée en '''2019''' dans le cadre du programme de Supergrappes d'innovation du gouvernement fédéral. Basée à Montréal, elle se spécialise dans l'application de l'[[intelligence artificielle]] à l'optimisation des chaînes d'approvisionnement.

''Scale AI is one of Canada's five Innovation Superclusters, launched in 2019. Based in Montreal, it specializes in applying artificial intelligence to supply chain optimization.''

== Chiffres clés ==

* '''Investissement gouvernemental''' : 230M$ (fédéral + provincial)
* '''Membres''' : 600+ organisations (PME, grandes entreprises, universités)
* '''Projets financés''' : 100+
* '''Emplois créés ou maintenus''' : 12,000+

== Mission ==

Scale AI vise à faire du Québec et du Canada un leader mondial dans l'application de l'[[IA générative|IA]] aux chaînes d'approvisionnement, en connectant :

* Les entreprises (grands donneurs d'ordres + PME)
* Les chercheurs universitaires ([[Mila - Institut québécois d'intelligence artificielle|Mila]], IVADO, universités)
* Les gouvernements (fédéral + provincial)
* Les organismes de formation

== Exemples de projets ==

* Optimisation de l'inventaire en temps réel pour les détaillants
* Prévision de la demande alimentaire pour réduire le gaspillage
* Logistique intelligente pour les ports et aéroports
* Traçabilité des produits dans la chaîne alimentaire
* Prédiction de la maintenance dans la fabrication

== Références ==

* [https://www.scaleai.ca Scale AI]
* [https://superclusters.ca Programme de Supergrappes d'innovation]

[[Category:Québec]]
[[Category:Intelligence artificielle]]
[[Category:Concepts numériques]]
""",

    "Langue française au Québec": """\
{{Infobox concept numérique
|titre_fr     = Langue française au Québec
|titre_en     = French language in Quebec
|domaine      = Québec
|langue       = fr-en
|année        = 1977
|organisation = Office québécois de la langue française (OQLF)
|description_fr = Le français, langue officielle et identitaire du Québec
|description_en = French, official and identity language of Quebec
|source       = https://dbpedia.org/resource/French_language_in_Canada
}}

== Le français au Québec ==

Le '''français''' est la langue officielle du Québec depuis l'adoption de la '''Charte de la langue française''' en 1977 (aussi appelée "Loi 101"). C'est la langue maternelle de plus de 77% de la population québécoise et la langue commune de tous les Québécois.

''French is the official language of Quebec since the adoption of the Charter of the French Language in 1977 (also called "Bill 101"). It is the mother tongue of more than 77% of the Quebec population.''

== Défis dans l'ère numérique / Challenges in the digital age ==

=== Intelligence artificielle et langue française ===

Le développement de l'[[intelligence artificielle]] pose des défis spécifiques pour la langue française au Québec :

* Les [[grands modèles de langage]] sont majoritairement entraînés en anglais, créant une disparité de qualité pour les applications en français
* Le français québécois (avec ses particularités lexicales et idiomes) est encore moins bien représenté que le français standard
* [[Mila - Institut québécois d'intelligence artificielle|Mila]] et ses partenaires travaillent au développement de modèles adaptés au français québécois

=== Francisation des termes technologiques ===

L'Office québécois de la langue française (OQLF) publie des recommandations pour franciser les termes technologiques :

{| class="wikitable"
! Terme anglais !! Terme français recommandé (OQLF)
|-
| Artificial intelligence || Intelligence artificielle
|-
| Machine learning || Apprentissage automatique
|-
| Cloud computing || Informatique en nuage
|-
| Deep learning || Apprentissage profond
|-
| Chatbot || Agent conversationnel
|-
| Digital sovereignty || Souveraineté numérique
|-
| Large language model || Grand modèle de langage
|}

=== Loi 101 et technologie ===

La Loi 101 s'applique au monde numérique : les logiciels, interfaces et services offerts aux consommateurs québécois doivent être disponibles en français.

== Semantic MediaWiki et le multilinguisme ==

Ce wiki utilise [[Semantic MediaWiki]] (SMW), qui supporte nativement le multilinguisme. Les propriétés et requêtes SMW sont définies et affichées en français, facilitant la création de bases de connaissances francophones.

== Références ==

* DBpedia: [https://dbpedia.org/resource/French_language_in_Canada French language in Canada]
* [https://www.oqlf.gouv.qc.ca OQLF — Office québécois de la langue française]

[[Category:Québec]]
[[Category:Concepts numériques]]
""",

    # ---- SEMANTIC MEDIAWIKI ----

    "Semantic MediaWiki": """\
{{Infobox concept numérique
|titre_fr     = Semantic MediaWiki
|titre_en     = Semantic MediaWiki
|domaine      = Intelligence artificielle
|langue       = fr-en
|année        = 2005
|organisation = SMW Project, Wikimedia Foundation
|description_fr = Extension MediaWiki pour la gestion sémantique des connaissances
|description_en = MediaWiki extension for semantic knowledge management
|source       = https://dbpedia.org/resource/Semantic_MediaWiki
}}

== Présentation ==

'''Semantic MediaWiki''' (SMW) est une extension libre de [[MediaWiki]], le logiciel qui fait fonctionner Wikipédia. Elle ajoute des capacités de '''web sémantique''' au wiki, permettant d'annoter les articles avec des données structurées et d'effectuer des requêtes intelligentes sur ce contenu.

''Semantic MediaWiki (SMW) is a free, open-source extension to MediaWiki — the software powering Wikipedia. It adds semantic web capabilities, enabling articles to be annotated with structured data and allowing intelligent queries on this content.''

== Fonctionnement ==

=== Annotations sémantiques ===

Dans SMW, les liens wiki ordinaires peuvent devenir des '''propriétés sémantiques''' :

<pre>
La capitale du Québec est [[a pour capitale::Québec City]].
Ce concept a été introduit en [[Année introduction::1956]].
[[Domaine::Intelligence artificielle]]
</pre>

=== Requêtes inline ({{#ask: ...}}) ===

Le parser <code>{{#ask: ...}}</code> permet d'interroger la base de connaissances :

<pre>
{{#ask: [[Domaine::Intelligence artificielle]]
 | ?Titre anglais
 | ?Année introduction
 | format=table
 | caption=Concepts d'IA
}}
</pre>

== Démonstration — Tous les concepts de ce wiki ==

{{#ask: [[Domaine::+]]
 | ?Domaine
 | ?Titre anglais
 | ?Langue
 | ?Année introduction
 | format=table
 | headers=show
 | mainlabel=Concept
 | caption=Base de connaissances complète — SMW Marketplace
 | limit=30
 | sort=Domaine
}}

== Ce projet — SMW Marketplace ==

Ce wiki est le démonstrateur technique du '''SMW Marketplace''' sur Azure, publié par '''[https://cotechnoe.com Cotechnoe]'''. Il démontre :

* Déploiement d'une base de connaissances sémantique sur Azure
* Contenu bilingue français/anglais sur l'IA et la souveraineté numérique
* Intégration avec Azure (VM, DNS, stockage, sécurité)
* [[Cloud souverain]] — hébergé sur Azure Canada Central (Montréal)

=== Architecture technique ===

{| class="wikitable"
! Composant !! Version !! Rôle
|-
| Azure VM || Ubuntu 22.04 LTS || Infrastructure
|-
| MediaWiki || 1.43 || Wiki engine
|-
| SemanticMediaWiki || 4.x || Semantic layer
|-
| MySQL || 8.0 || Database
|-
| Apache + PHP-FPM || 2.4 + 8.2 || Web server
|-
| Azure Canada Central || — || Sovereign cloud hosting
|}

== Références ==

* [https://www.semantic-mediawiki.org Semantic MediaWiki]
* [https://cotechnoe.com Cotechnoe]
* DBpedia: [https://dbpedia.org/resource/Semantic_MediaWiki Semantic MediaWiki]

[[Category:Intelligence artificielle]]
[[Category:Concepts numériques]]
""",

    # ---- PORTAL ----

    "Portail:Numérique et IA": """\
<div style="background:linear-gradient(135deg, #1a237e 0%, #0d47a1 50%, #1565c0 100%); color:white; padding:30px; border-radius:8px; margin-bottom:24px;">
<h1 style="color:white; font-size:2em; margin:0 0 10px 0;">Portail — Numérique et IA</h1>
<p style="font-size:1.1em; margin:0 0 8px 0; opacity:0.92;">Base de connaissances sémantique bilingue | Semantic Bilingual Knowledge Base</p>
<p style="font-size:0.95em; margin:0; opacity:0.78;">Intelligence artificielle · Souveraineté numérique · Québec</p>
</div>

== Intelligence artificielle ==

{{#ask: [[Domaine::Intelligence artificielle]]
 | ?Titre anglais
 | ?Année introduction
 | ?Organisation clé
 | format=table
 | headers=show
 | mainlabel=Concept (FR)
 | caption=Concepts d'intelligence artificielle dans ce wiki
 | limit=20
 | sort=Année introduction
}}

== Souveraineté numérique ==

{{#ask: [[Domaine::Souveraineté numérique]]
 | ?Titre anglais
 | ?Année introduction
 | ?Organisation clé
 | format=table
 | headers=show
 | mainlabel=Concept (FR)
 | caption=Concepts de souveraineté numérique dans ce wiki
 | limit=20
}}

== Québec ==

{{#ask: [[Domaine::Québec]]
 | ?Titre anglais
 | ?Année introduction
 | ?Organisation clé
 | format=table
 | headers=show
 | mainlabel=Concept (FR)
 | caption=Concepts liés au Québec dans ce wiki
 | limit=20
}}

== Vue d'ensemble / Overview ==

{{#ask: [[Domaine::+]]
 | ?Domaine
 | ?Titre anglais
 | ?Langue
 | format=table
 | headers=show
 | mainlabel=Article
 | caption=Tous les articles sémantiques / All semantic articles
 | limit=50
 | sort=Domaine
}}

== À propos / About ==

Ce portail est une démonstration de '''[[Semantic MediaWiki]]''' déployé sur '''Azure Canada Central''' dans le cadre du '''SMW Marketplace''' ([https://cotechnoe.com Cotechnoe]).

''This portal demonstrates Semantic MediaWiki deployed on Azure Canada Central as part of the SMW Marketplace (Cotechnoe). It showcases bilingual FR/EN semantic knowledge management.''

[[Category:Concepts numériques]]
""",

    # ---- MAIN PAGE ----

    "Main Page": """\
<div style="background:linear-gradient(135deg, #1a237e 0%, #283593 100%); color:white; padding:30px; border-radius:8px; margin-bottom:24px; text-align:center;">
<h1 style="color:white; font-size:2.4em; margin:0 0 10px 0;">SMW Marketplace</h1>
<h2 style="color:#bbdefb; font-size:1.3em; margin:0 0 15px 0; font-weight:normal;">Semantic MediaWiki sur Azure | Semantic MediaWiki on Azure</h2>
<p style="opacity:0.9; margin:0; font-size:1.05em;">Base de connaissances sémantique · Intelligence artificielle · Souveraineté numérique · Québec</p>
</div>

== Bienvenue / Welcome ==

'''SMW Marketplace''' est une plateforme de gestion des connaissances sémantique basée sur '''[[Semantic MediaWiki]]''', déployée sur '''Azure Canada Central''' (Montréal, Québec). Ce wiki démontre les capacités de SMW pour créer une base de connaissances structurée, interrogeable et bilingue.

''SMW Marketplace is a semantic knowledge management platform based on Semantic MediaWiki, deployed on Azure Canada Central. This wiki demonstrates SMW capabilities for a structured, queryable, and bilingual knowledge base.''

Explorez le portail thématique : '''[[Portail:Numérique et IA|Portail — Numérique et IA]]'''

== Thèmes principaux / Main themes ==

=== Intelligence artificielle ===

* [[Intelligence artificielle]] / Artificial intelligence
* [[Apprentissage automatique]] / Machine learning
* [[Grands modèles de langage]] / Large language models
* [[IA générative]] / Generative AI
* [[Mila - Institut québécois d'intelligence artificielle]] / Mila Quebec AI Institute

=== Souveraineté numérique ===

* [[Souveraineté numérique]] / Digital sovereignty
* [[RGPD]] / GDPR
* [[Cloud souverain]] / Sovereign cloud
* [[Protection des données personnelles]] / Personal data protection

=== Québec ===

* [[Québec (province)]] / Quebec
* [[Scale AI (Québec)]] / Scale AI
* [[Langue française au Québec]] / French language in Quebec

=== À propos de SMW ===

* [[Semantic MediaWiki]]
* [[Special:Statistics|Statistiques du wiki / Wiki statistics]]
* [[Special:SemanticMediaWiki|État de SMW / SMW status]]

== Requête sémantique en direct / Live semantic query ==

{{#ask: [[Domaine::+]]
 | ?Domaine
 | ?Titre anglais
 | ?Langue
 | format=table
 | headers=show
 | mainlabel=Article
 | caption=Articles sémantiques disponibles / Available semantic articles
 | limit=20
 | sort=Domaine
}}

----
<small>''SMW Marketplace by [https://cotechnoe.com Cotechnoe] · Hébergé sur Azure Canada Central · [[Semantic MediaWiki]] 4.x + MediaWiki 1.43''</small>
""",
}

# ============================================================
# API CLIENT
# ============================================================

def make_opener():
    """Create an HTTPS opener that ignores self-signed certs and handles cookies."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(
        urllib.request.HTTPSHandler(context=ctx),
        urllib.request.HTTPCookieProcessor(cj)
    )
    return opener


def api_post(opener, api_url, params):
    """POST to the MediaWiki API and return parsed JSON."""
    data = urllib.parse.urlencode(params).encode("utf-8")
    req = urllib.request.Request(api_url, data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
    req.add_header("User-Agent", "SMWPopulateScript/1.0 (populate-wiki.py)")
    with opener.open(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def login(opener, api_url, username, password):
    """Authenticate to the MediaWiki API."""
    # Step 1: get login token
    r = api_post(opener, api_url, {
        "action": "query",
        "meta": "tokens",
        "type": "login",
        "format": "json",
    })
    token = r["query"]["tokens"]["logintoken"]

    # Step 2: log in
    r = api_post(opener, api_url, {
        "action": "login",
        "lgname": username,
        "lgpassword": password,
        "lgtoken": token,
        "format": "json",
    })
    result = r["login"]["result"]
    if result != "Success":
        raise RuntimeError(f"Login failed: {result} — {r['login']}")
    print(f"  Logged in as {r['login']['lgusername']}")


def get_csrf_token(opener, api_url):
    """Get a CSRF token for write operations."""
    r = api_post(opener, api_url, {
        "action": "query",
        "meta": "tokens",
        "format": "json",
    })
    return r["query"]["tokens"]["csrftoken"]


def create_or_update_page(opener, api_url, csrf_token, title, content, summary="SMW populate"):
    """Create or update a wiki page. Returns True on success."""
    r = api_post(opener, api_url, {
        "action": "edit",
        "title": title,
        "text": content,
        "summary": summary,
        "token": csrf_token,
        "format": "json",
    })
    if "edit" in r and r["edit"].get("result") == "Success":
        action = "CREATED" if r["edit"].get("new") is not None else "UPDATED"
        print(f"  {action}: [[{title}]]")
        return True
    else:
        print(f"  FAILED: [[{title}]] — {r.get('error', r)}")
        return False


# ============================================================
# MAIN
# ============================================================

def main():
    parser = argparse.ArgumentParser(
        description="Populate SMW wiki with bilingual FR/EN content on AI, digital sovereignty, and Quebec"
    )
    parser.add_argument("--wiki-url", default=DEFAULT_WIKI,
                        help=f"Base URL of the wiki (default: {DEFAULT_WIKI})")
    parser.add_argument("--user", default=DEFAULT_USER,
                        help=f"Wiki admin username (default: {DEFAULT_USER})")
    parser.add_argument("--password", default=DEFAULT_PASS,
                        help="Wiki admin password")
    args = parser.parse_args()

    api_url = f"{args.wiki_url}/api.php"

    print()
    print("=" * 64)
    print("  SMW Wiki Populate Script")
    print(f"  Wiki: {args.wiki_url}")
    print(f"  User: {args.user}")
    print("=" * 64)

    opener = make_opener()

    print("\nAuthentication...")
    login(opener, api_url, args.user, args.password)
    csrf_token = get_csrf_token(opener, api_url)

    total = 0
    success = 0

    sections = [
        ("SMW Properties", PROPERTIES, "Add SMW property definition"),
        ("Templates",      TEMPLATES,  "Add wiki template"),
        ("Categories",     CATEGORIES, "Add category page"),
        ("Content Pages",  PAGES,      "Add bilingual content — SMW Marketplace demo"),
    ]

    for label, pages_dict, edit_summary in sections:
        print(f"\n{label} ({len(pages_dict)} pages)...")
        for title, content in pages_dict.items():
            total += 1
            ok = create_or_update_page(opener, api_url, csrf_token, title, content, edit_summary)
            if ok:
                success += 1
            time.sleep(0.4)   # be kind to the server

    print()
    print("=" * 64)
    print(f"  Done: {success}/{total} pages created/updated")
    print(f"  Wiki:   {args.wiki_url}/wiki/Main_Page")
    print(f"  Portal: {args.wiki_url}/wiki/Portail:Num%C3%A9rique_et_IA")
    print("=" * 64)
    print()

    if success < total:
        sys.exit(1)


if __name__ == "__main__":
    main()
