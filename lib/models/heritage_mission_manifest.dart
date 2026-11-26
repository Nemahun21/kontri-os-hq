/// Shared QA preview contract, mirrored byte-for-byte in Kontrios and HQ.
/// Versioned source references, not a published mission or rights clearance.
const heritageMissionId = 'monuments-and-relics';
const heritageMissionVersion = 1;
class HeritageStop {
  final String id, title, objective, story, gap;
  final List<String> lessonIds, questionIds, sources;
  const HeritageStop(this.id,this.title,this.objective,this.story,this.gap,
    this.lessonIds,this.questionIds,this.sources);
}
const heritageStops = [
  HeritageStop('cotton-tree','Cotton Tree','Memory and identity',
    'Freetown’s historic Cotton Tree became a symbol of freedom. The tree fell during a storm in May 2023. Its place in the city’s collective memory remains important.',
    'Review founding-history wording; obtain a rights-cleared image with its date.',
    ['b8eb5b59-369c-4922-bf68-27a8dc3f3d6a'],
    ['ab728eb6-8a48-4e31-b1f0-960670b7cad8'],
    ['https://www.abc.net.au/news/2023-05-26/sierra-leone-loses-historic-tree-symbol-freedom-rainstorm/102395116']),
  HeritageStop('bunce-island','Bunce Island','Remembering the past',
    'Bunce Island was established as a slave-trading station around 1670. Enslaved Africans were forcibly transported from there across the Atlantic. Preserving the site helps us remember this history and its continuing significance.',
    'Review respectful language and historical context; secure an authentic visual.',
    ['5b4866fd-e313-4702-8036-60ee437c783d','b1ee8d62-dadc-41bc-a48f-9ed5d6f786a5'],
    ['92f60945-f1e2-46bc-a915-7c350345256e','929f0991-f268-4e03-91fc-1e3ba86b6b53'],
    ['https://whc.unesco.org/en/tentativelists/5745/','https://www.wmf.org/projects/bunce-island']),
  HeritageStop('national-museum','National Museum','Discover material culture',
    'The National Museum in central Freetown opened in 1957. Its collection includes a crouching soapstone figure known as a Nomoli in Mende (accession SLNM.1971.02.07). The precise age of such figures is uncertain.',
    'Curator and cultural review of the specific object; photograph permission and new object-level questions.',
    ['11619686-24ea-4db5-aef5-e191b7162dc3'],
    ['994367b1-442c-4be0-bad2-a03c039ace04','070a05f9-eda1-48fa-9350-1500fff310c9'],
    ['https://www.sierraleoneheritage.org/museum','https://sierraleoneheritage.org/item/SLNM.1971.02.07/nomoli']),
  HeritageStop('railway-museum','National Railway Museum','Discover industrial heritage',
    'The museum opened in 2005 at the former railway workshops in Cline Town, Freetown. Its collection includes the Beyer-Garratt steam locomotive No. 73, built in 1955.',
    'Confirm exhibit details and secure permission for a photograph of the actual locomotive.',
    ['11619686-24ea-4db5-aef5-e191b7162dc3'],
    ['6cf223c6-cd6c-4496-82f5-aff0e100109f'],
    ['https://sierraleoneheritage.org/museum/railway-museum']),
];

bool supportedHeritageQuestion(Map<String,dynamic> row) {
  if (!(row['question'] is String) || (row['question'] as String).trim().isEmpty) return false;
  final options=row['options'];
  final answer=row['correct_answer_index'];
  if(options is! List || options.isEmpty || options.any((o)=>o is! String) ||
      answer is! int || answer<0 || answer>=options.length) return false;
  switch(row['type']){
    case 'multipleChoice': return options.length>=2;
    case 'trueFalse': return options.length==2 && options[0].toString().toLowerCase()=='true' && options[1].toString().toLowerCase()=='false';
    case 'textInput': return answer==0 && (options.first as String).trim().isNotEmpty;
    default: return false;
  }
}
