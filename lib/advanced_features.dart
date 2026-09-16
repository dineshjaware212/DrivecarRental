part of 'main.dart';

const bookingStatuses=<String>[
  'Enquiry','Token Pending','Token Received','Confirmed','Vehicle Delivered',
  'Active Rental','Returned','Payment Pending','Completed','Cancelled'
];

Future<List<String>> _pickAndStoreMedia(String folder,{bool multiple=false})async{
  final result=await FilePicker.platform.pickFiles(
    type:FileType.custom,allowMultiple:multiple,
    allowedExtensions:['jpg','jpeg','png','webp','mp4','mov']);
  if(result==null)return[];
  final root=await getApplicationDocumentsDirectory();final dir=Directory('${root.path}/$folder');
  await dir.create(recursive:true);final saved=<String>[];
  for(final item in result.files){
    if(item.path==null)continue;final ext=item.path!.contains('.')?item.path!.substring(item.path!.lastIndexOf('.')):'';
    final target=File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${saved.length}$ext');
    await File(item.path!).copy(target.path);saved.add(target.path);
  }
  return saved;
}

class OperationsHubPage extends StatelessWidget{
  const OperationsHubPage({super.key});
  @override Widget build(BuildContext context){
    final items=<({String title,IconData icon,Widget page})>[
      (title:'Availability Calendar',icon:Icons.calendar_month,page:const AvailabilityPage()),
      (title:'Pickup / Return Inspections',icon:Icons.fact_check,page:const InspectionsPage()),
      (title:'Customer Documents',icon:Icons.badge,page:const CustomerDocumentsPage()),
      (title:'Expenses & Profit',icon:Icons.analytics,page:const ExpensesReportPage()),
    ];
    return Scaffold(appBar:AppBar(title:const Text('Rental Operations')),body:GridView.builder(
      padding:const EdgeInsets.all(16),itemCount:items.length,
      gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.15),
      itemBuilder:(_,i){final item=items[i];return Card(child:InkWell(borderRadius:BorderRadius.circular(12),
        onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>item.page)),
        child:Padding(padding:const EdgeInsets.all(16),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Icon(item.icon,size:42,color:Theme.of(context).colorScheme.primary),const SizedBox(height:10),
          Text(item.title,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold)),
        ]))));}));
  }
}

class AvailabilityPage extends StatefulWidget{
  const AvailabilityPage({super.key});
  @override State<AvailabilityPage> createState()=>_AvailabilityPageState();
}
class _AvailabilityPageState extends State<AvailabilityPage>{
  List<List<String>> cars=[],bookings=[];
  DateTimeRange range=DateTimeRange(start:DateTime.now(),end:DateTime.now().add(const Duration(days:1)));
  @override void initState(){super.initState();load();}
  Future<void> load()async{cars=await db.rows('Cars');bookings=await db.rows('Bookings');if(mounted)setState((){});}
  bool free(List<String> car)=>!bookings.any((b){
    if(b.length<8||b[2]!=car[0]||b[7]=='Cancelled')return false;
    final start=DateTime.tryParse(b[3]),end=DateTime.tryParse(b[4]);
    return start!=null&&end!=null&&range.start.isBefore(end)&&range.end.isAfter(start);
  });
  Future<void> choose()async{final value=await showDateRangePicker(context:context,firstDate:DateTime(2020),lastDate:DateTime(2100),initialDateRange:range);if(value!=null)setState(()=>range=value);}
  List<List<String>> get upcomingReturns=>bookings.where((b){
    if(b.length<8||b[7]=='Cancelled'||b[7]=='Completed')return false;final end=DateTime.tryParse(b[4]);
    if(end==null)return false;final days=end.difference(DateTime.now()).inDays;return days>=0&&days<=2;
  }).toList();
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Availability Calendar')),body:ListView(
    padding:const EdgeInsets.all(14),children:[
      OutlinedButton.icon(onPressed:choose,icon:const Icon(Icons.date_range),label:Text('${DateFormat('dd MMM yyyy').format(range.start)} – ${DateFormat('dd MMM yyyy').format(range.end)}')),
      if(upcomingReturns.isNotEmpty)Card(color:Colors.orange.shade50,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Upcoming Returns',style:TextStyle(fontWeight:FontWeight.bold)),
        ...upcomingReturns.map((b)=>Text('Booking ${shortBookingId(b[0])} • ${DateFormat('dd MMM yyyy').format(DateTime.parse(b[4]))}')),
      ]))),
      const SizedBox(height:8),
      ...cars.map((car){final available=free(car);return Card(child:ListTile(
        leading:Icon(available?Icons.check_circle:Icons.block,color:available?Colors.green:Colors.red),
        title:Text(car.length>1?car[1]:'Car'),subtitle:Text('${car.length>2?car[2]:''} • INR ${car.length>3?car[3]:'0'}/day'),
        trailing:Text(available?'AVAILABLE':'BOOKED',style:TextStyle(fontWeight:FontWeight.bold,color:available?Colors.green:Colors.red))));}),
    ]));
}

class CustomerDocumentsPage extends StatefulWidget{
  const CustomerDocumentsPage({super.key});
  @override State<CustomerDocumentsPage> createState()=>_CustomerDocumentsPageState();
}
class _CustomerDocumentsPageState extends State<CustomerDocumentsPage>{
  List<List<String>> customers=[];String? customerId;DateTime? expiry;
  @override void initState(){super.initState();load();}
  Future<void> load()async{customers=await db.rows('Customers');if(mounted)setState((){});}
  List<String>? get customer{for(final r in customers){if(r.isNotEmpty&&r[0]==customerId)return r;}return null;}
  Future<void> upload(int column,String header,String label)async{
    if(customerId==null)return;final files=await _pickAndStoreMedia('customer_documents');if(files.isEmpty)return;
    await db.setValueById('Customers',customerId!,column,files.first,header:header);await load();
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$label uploaded.')));
  }
  Future<void> setExpiry()async{
    if(customerId==null)return;final date=await showDatePicker(context:context,initialDate:expiry??DateTime.now().add(const Duration(days:365)),firstDate:DateTime.now(),lastDate:DateTime(2100));
    if(date!=null){expiry=date;await db.setValueById('Customers',customerId!,9,date.toIso8601String(),header:'license_expiry');await load();}
  }
  Widget docButton(int col,String header,String label,IconData icon){
    final path=customer!=null&&customer!.length>col?customer![col]:'';return ListTile(leading:Icon(icon),title:Text(label),
      subtitle:Text(path.isEmpty?'Not uploaded':'Uploaded'),trailing:FilledButton(onPressed:()=>upload(col,header,label),child:Text(path.isEmpty?'Upload':'Replace')));
  }
  @override Widget build(BuildContext context){
    final row=customer;if(row!=null&&row.length>9&&row[9].isNotEmpty)expiry=DateTime.tryParse(row[9]);
    final expiring=expiry!=null&&expiry!.difference(DateTime.now()).inDays<=30;
    return Scaffold(appBar:AppBar(title:const Text('Customer Documents')),body:ListView(padding:const EdgeInsets.all(14),children:[
      DropdownButtonFormField<String>(value:customerId,isExpanded:true,decoration:const InputDecoration(labelText:'Select customer',border:OutlineInputBorder()),
        items:customers.map((r)=>DropdownMenuItem(value:r[0],child:Text(r.length>1?r[1]:r[0]))).toList(),onChanged:(v)=>setState(()=>customerId=v)),
      if(customerId!=null)...[
        const SizedBox(height:12),docButton(6,'driving_license_path','Driving Licence',Icons.credit_card),
        docButton(7,'aadhaar_path','Aadhaar / ID Proof',Icons.badge),docButton(8,'pan_path','PAN Card',Icons.assignment_ind),
        ListTile(leading:Icon(Icons.event,color:expiring?Colors.red:null),title:const Text('Driving Licence Expiry'),
          subtitle:Text(expiry==null?'Not set':DateFormat('dd MMM yyyy').format(expiry!)),
          trailing:OutlinedButton(onPressed:setExpiry,child:const Text('Set Date'))),
        if(expiring)const Card(color:Color(0xffffebee),child:Padding(padding:EdgeInsets.all(12),child:Text('Driving licence expires within 30 days.',style:TextStyle(color:Colors.red,fontWeight:FontWeight.bold)))),
      ]
    ]));
  }
}

class InspectionsPage extends StatefulWidget{
  const InspectionsPage({super.key});
  @override State<InspectionsPage> createState()=>_InspectionsPageState();
}
class _InspectionsPageState extends State<InspectionsPage>{
  List<List<String>> bookings=[],inspections=[];String? bookingId;String type='Pickup';
  final odometer=TextEditingController(),fuel=TextEditingController(),damage=TextEditingController();
  final signature=SignatureController(penStrokeWidth:3,penColor:Colors.indigo);List<String> media=[];bool busy=false;
  @override void initState(){super.initState();load();}
  Future<void> load()async{bookings=await db.rows('Bookings');inspections=await db.rows('Inspections');if(mounted)setState((){});}
  Future<void> pickMedia()async{final files=await _pickAndStoreMedia('inspection_media',multiple:true);setState(()=>media.addAll(files));}
  Future<void> save()async{
    if(bookingId==null||odometer.text.trim().isEmpty||signature.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Select a booking, enter odometer, and obtain a signature.')));return;}
    setState(()=>busy=true);
    try{
      final root=await getApplicationDocumentsDirectory();final sigDir=Directory('${root.path}/inspection_signatures');await sigDir.create(recursive:true);
      final sigFile=File('${sigDir.path}/${newId()}.png');await sigFile.writeAsBytes((await signature.toPngBytes())!);
      final pdf=pw.Document();final widgets=<pw.Widget>[
        pw.Text('$type VEHICLE INSPECTION',style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:12),
        AgreementService._pdfSection('Inspection details',[[ 'Booking ID',bookingId!],['Odometer',odometer.text],['Fuel level','${fuel.text}%'],['Damage / notes',damage.text],['Created',DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())]]),
        pw.Text('Customer acknowledgement',style:pw.TextStyle(fontWeight:pw.FontWeight.bold)),
        pw.Image(pw.MemoryImage(await sigFile.readAsBytes()),height:90),pw.SizedBox(height:12),
      ];
      for(final path in media.where((p)=>!p.toLowerCase().endsWith('.mp4')&&!p.toLowerCase().endsWith('.mov')).take(6)){
        final f=File(path);if(await f.exists())widgets.add(pw.Padding(padding:const pw.EdgeInsets.only(bottom:10),child:pw.Image(pw.MemoryImage(await f.readAsBytes()),height:180,fit:pw.BoxFit.contain)));
      }
      pdf.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,build:(_)=>widgets));
      final pdfDir=Directory('${root.path}/inspections');await pdfDir.create(recursive:true);final pdfFile=File('${pdfDir.path}/${type}_Inspection_${shortBookingId(bookingId!)}.pdf');
      await pdfFile.writeAsBytes(await pdf.save(),flush:true);
      await db.add('Inspections',[newId(),bookingId,type,odometer.text,double.tryParse(fuel.text)??0,damage.text,media.join('|'),sigFile.path,pdfFile.path,DateTime.now().toIso8601String()]);
      await Share.shareXFiles([XFile(pdfFile.path)],text:'$type inspection for booking ${shortBookingId(bookingId!)}');
      odometer.clear();fuel.clear();damage.clear();signature.clear();media=[];await load();
    }finally{if(mounted)setState(()=>busy=false);}
  }
  @override void dispose(){odometer.dispose();fuel.dispose();damage.dispose();signature.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Pickup / Return Inspection')),body:ListView(padding:const EdgeInsets.all(14),children:[
    DropdownButtonFormField<String>(value:bookingId,isExpanded:true,decoration:const InputDecoration(labelText:'Booking',border:OutlineInputBorder()),
      items:bookings.map((r)=>DropdownMenuItem(value:r[0],child:Text('Booking ${shortBookingId(r[0])}'))).toList(),onChanged:(v)=>setState(()=>bookingId=v)),
    const SizedBox(height:8),DropdownButtonFormField<String>(value:type,decoration:const InputDecoration(labelText:'Inspection type',border:OutlineInputBorder()),
      items:const ['Pickup','Return'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>type=v??'Pickup')),
    const SizedBox(height:8),field(odometer,'Odometer reading',number:true),field(fuel,'Fuel level (%)',number:true),field(damage,'Existing damage / return notes'),
    OutlinedButton.icon(onPressed:pickMedia,icon:const Icon(Icons.add_a_photo),label:Text('Add photos or videos (${media.length})')),
    const SizedBox(height:8),const Text('Customer acknowledgement signature',style:TextStyle(fontWeight:FontWeight.bold)),
    Container(height:150,decoration:BoxDecoration(border:Border.all(color:Colors.grey)),child:Signature(controller:signature,backgroundColor:Colors.white)),
    TextButton(onPressed:signature.clear,child:const Text('Clear Signature')),
    FilledButton.icon(onPressed:busy?null:save,icon:const Icon(Icons.picture_as_pdf),label:const Text('Save & Share Inspection PDF')),
    const Divider(height:28),const Text('Saved Inspections',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    ...inspections.reversed.map((r)=>ListTile(leading:const Icon(Icons.fact_check),title:Text('${r.length>2?r[2]:''} • Booking ${r.length>1?shortBookingId(r[1]):''}'),subtitle:Text(r.length>9?r[9]:''),
      onTap:r.length>8&&File(r[8]).existsSync()?()=>Share.shareXFiles([XFile(r[8])]):null)),
  ]));
}

class ReturnChargesPage extends StatefulWidget{
  final List<String> booking;const ReturnChargesPage({super.key,required this.booking});
  @override State<ReturnChargesPage> createState()=>_ReturnChargesPageState();
}
class _ReturnChargesPageState extends State<ReturnChargesPage>{
  final returnOdo=TextEditingController(),lateHours=TextEditingController(),fuelCharge=TextEditingController(),damageCharge=TextEditingController(),washingCharge=TextEditingController();
  double pickupOdo=0,dailyRate=0;bool sevenSeater=false;List<List<String>> returns=[];
  int get days{final s=DateTime.tryParse(widget.booking[3]),e=DateTime.tryParse(widget.booking[4]);if(s==null||e==null)return 1;final d=e.difference(s).inDays;return d<1?1:d;}
  double n(TextEditingController c)=>double.tryParse(c.text)??0;
  double get extraKm{final value=n(returnOdo)-pickupOdo-(days*350);return value<0?0:value;}
  double get kmCharge=>extraKm*(sevenSeater?7:5);
  double get lateFee{final h=n(lateHours);return h>3?dailyRate:h*200;}
  double get total=>kmCharge+lateFee+n(fuelCharge)+n(damageCharge)+n(washingCharge);
  @override void initState(){super.initState();for(final c in [returnOdo,lateHours,fuelCharge,damageCharge,washingCharge]){c.addListener(changed);}load();}
  void changed(){if(mounted)setState((){});}
  Future<void> load()async{
    returns=await db.rows('Returns');final inspections=await db.rows('Inspections');final cars=await db.rows('Cars');
    for(final r in inspections.reversed){if(r.length>3&&r[1]==widget.booking[0]&&r[2]=='Pickup'){pickupOdo=double.tryParse(r[3])??0;break;}}
    for(final r in cars){if(r.isNotEmpty&&r[0]==widget.booking[2]){dailyRate=r.length>3?double.tryParse(r[3])??0:0;sevenSeater=r.length>1&&r[1].contains('7');break;}}
    if(mounted)setState((){});
  }
  Future<void> save()async{
    if(returns.any((r)=>r.length>1&&r[1]==widget.booking[0])){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Return charges have already been recorded for this booking.')));return;}
    await db.add('Returns',[newId(),widget.booking[0],n(returnOdo),extraKm,kmCharge,n(lateHours),lateFee,n(fuelCharge),n(damageCharge),n(washingCharge),total,DateTime.now().toIso8601String()]);
    final oldTotal=widget.booking.length>5?double.tryParse(widget.booking[5])??0:0;
    await db.setValueById('Bookings',widget.booking[0],5,oldTotal+total,header:'amount');
    await db.setValueById('Bookings',widget.booking[0],7,'Payment Pending',header:'status');
    if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Return charges of INR ${total.toStringAsFixed(2)} added.')));Navigator.pop(context);}
  }
  @override void dispose(){for(final c in [returnOdo,lateHours,fuelCharge,damageCharge,washingCharge]){c.dispose();}super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Return & Extra Charges')),body:ListView(padding:const EdgeInsets.all(14),children:[
    Text('Booking ${shortBookingId(widget.booking[0])}',style:Theme.of(context).textTheme.titleLarge),
    Text('Included mileage: ${days*350} km • Extra rate: INR ${sevenSeater?7:5}/km'),const SizedBox(height:10),
    field(returnOdo,'Return odometer',number:true),field(lateHours,'Late hours',number:true),field(fuelCharge,'Fuel charge',number:true),field(damageCharge,'Damage charge',number:true),field(washingCharge,'Washing charge',number:true),
    Card(color:Theme.of(context).colorScheme.primaryContainer,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Extra kilometres: ${extraKm.toStringAsFixed(1)} • INR ${kmCharge.toStringAsFixed(2)}'),Text('Late fee: INR ${lateFee.toStringAsFixed(2)}'),
      Text('Total additional charges: INR ${total.toStringAsFixed(2)}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    ]))),FilledButton.icon(onPressed:save,icon:const Icon(Icons.save),label:const Text('Apply Return Charges')),
  ]));
}

Future<void> showBookingStatusDialog(BuildContext context,List<String> booking,Future<void> Function() reload)async{
  var status=booking.length>7?booking[7]:'Enquiry';if(!bookingStatuses.contains(status))status='Enquiry';
  final chosen=await showDialog<String>(context:context,builder:(c)=>AlertDialog(title:const Text('Booking Status'),content:DropdownButtonFormField<String>(value:status,
    items:bookingStatuses.map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>status=v??status),
    actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,status),child:const Text('Save'))]));
  if(chosen!=null){await db.setValueById('Bookings',booking[0],7,chosen,header:'status');await reload();}
}

Future<void> shareBookingInvoice(List<String> booking,List<List<String>> customers,List<List<String>> cars,List<List<String>> payments)async{
  String customer=booking.length>1?booking[1]:'';String car=booking.length>2?booking[2]:'';
  for(final r in customers){if(r.isNotEmpty&&r[0]==customer){customer=r.length>1?r[1]:customer;break;}}
  for(final r in cars){if(r.isNotEmpty&&r[0]==car){car=r.length>2?'${r[1]} (${r[2]})':r[1];break;}}
  final total=booking.length>5?double.tryParse(booking[5])??0:0;
  final paid=payments.where((r)=>r.length>2&&r[1]==booking[0]).fold<double>(0,(s,r)=>s+(double.tryParse(r[2])??0));final due=(total-paid)<0?0:total-paid;
  final pdf=pw.Document();pdf.addPage(pw.Page(build:(_)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
    pw.Text(due<=0?'PAYMENT RECEIPT':'RENTAL INVOICE',style:pw.TextStyle(fontSize:22,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:16),
    AgreementService._pdfSection('Details',[[ 'Booking ID',booking[0]],['Customer',customer],['Vehicle',car],['Rental total','INR ${total.toStringAsFixed(2)}'],['Amount paid','INR ${paid.toStringAsFixed(2)}'],['Balance due','INR ${due.toStringAsFixed(2)}'],['Status',booking.length>7?booking[7]:'']]),
    pw.Text('Thank you for choosing DriveRent.'),
  ])));
  final root=await getApplicationDocumentsDirectory();final dir=Directory('${root.path}/invoices');await dir.create(recursive:true);
  final file=File('${dir.path}/${due<=0?'Receipt':'Invoice'}_${shortBookingId(booking[0])}.pdf');await file.writeAsBytes(await pdf.save(),flush:true);
  await Share.shareXFiles([XFile(file.path)],text:'${due<=0?'Payment receipt':'Rental invoice'} for booking ${shortBookingId(booking[0])}');
}

class WhatsAppTemplatesPage extends StatelessWidget{
  final List<String> booking;final String customerName,customerPhone,carName;
  const WhatsAppTemplatesPage({super.key,required this.booking,required this.customerName,required this.customerPhone,required this.carName});
  Future<void> send(BuildContext context,String title,String body)async{
    var phone=customerPhone.replaceAll(RegExp(r'[^0-9]'),'');if(phone.length==10)phone='91$phone';
    if(phone.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Customer phone number is missing.')));return;}
    final message='Hello $customerName,\n\n$body\n\nBooking: ${shortBookingId(booking[0])}\nVehicle: $carName\n\nThank you,\nDriveRent';
    await launchUrl(Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}'),mode:LaunchMode.externalApplication);
  }
  @override Widget build(BuildContext context){
    final templates=<String,String>{
      'Token Payment Request':'Please pay the INR 500 token amount to confirm your booking.',
      'Booking Confirmation':'Your self-drive car booking is confirmed.',
      'Pickup Reminder':'This is a reminder that your vehicle pickup is scheduled soon. Please carry your original driving licence and ID proof.',
      'Documents Required':'Please share your valid driving licence, Aadhaar or ID proof, and address proof to complete the booking.',
      'Remaining Payment':'Please pay the remaining booking amount before vehicle delivery.',
      'Return Reminder':'This is a reminder to return the vehicle at the agreed date and time to avoid late charges.',
      'Late Return Warning':'The vehicle return is overdue. A late fee of INR 200 per hour applies, and after three hours an additional day charge applies.',
      'Thank You':'Thank you for choosing DriveRent. We hope you had a safe and pleasant journey.',
    };
    return Scaffold(appBar:AppBar(title:const Text('WhatsApp Templates')),body:ListView(padding:const EdgeInsets.all(14),children:templates.entries.map((e)=>Card(child:ListTile(
      leading:const Icon(Icons.chat,color:Colors.green),title:Text(e.key),subtitle:Text(e.value,maxLines:2,overflow:TextOverflow.ellipsis),trailing:const Icon(Icons.send),onTap:()=>send(context,e.key,e.value)))).toList()));
  }
}

class ExpensesReportPage extends StatefulWidget{
  const ExpensesReportPage({super.key});
  @override State<ExpensesReportPage> createState()=>_ExpensesReportPageState();
}
class _ExpensesReportPageState extends State<ExpensesReportPage>{
  List<List<String>> expenses=[],payments=[],cars=[],bookings=[];String? carId;String category='Maintenance';
  final amount=TextEditingController(),notes=TextEditingController();
  @override void initState(){super.initState();load();}
  Future<void> load()async{expenses=await db.rows('Expenses');payments=await db.rows('Payments');cars=await db.rows('Cars');bookings=await db.rows('Bookings');if(mounted)setState((){});}
  double get income=>payments.fold<double>(0,(s,r)=>s+(r.length>2?double.tryParse(r[2])??0:0));
  double get cost=>expenses.fold<double>(0,(s,r)=>s+(r.length>3?double.tryParse(r[3])??0:0));
  double get pending{
    final billed=bookings.fold<double>(0,(s,r)=>s+(r.length>5?double.tryParse(r[5])??0:0));final value=billed-income;return value<0?0:value;
  }
  bool currentMonth(String value){final d=DateTime.tryParse(value);final now=DateTime.now();return d!=null&&d.year==now.year&&d.month==now.month;}
  double get monthIncome=>payments.where((r)=>r.length>4&&currentMonth(r[4])).fold<double>(0,(s,r)=>s+(double.tryParse(r[2])??0));
  double get monthCost=>expenses.where((r)=>r.length>4&&currentMonth(r[4])).fold<double>(0,(s,r)=>s+(double.tryParse(r[3])??0));
  String get bestCar{
    String best='No data';double bestProfit=-double.maxFinite;
    for(final car in cars){final id=car[0];final bookingIds=bookings.where((b)=>b.length>2&&b[2]==id).map((b)=>b[0]).toSet();
      final revenue=payments.where((p)=>p.length>2&&bookingIds.contains(p[1])).fold<double>(0,(s,p)=>s+(double.tryParse(p[2])??0));
      final vehicleCost=expenses.where((e)=>e.length>3&&e[1]==id).fold<double>(0,(s,e)=>s+(double.tryParse(e[3])??0));
      if(revenue-vehicleCost>bestProfit){bestProfit=revenue-vehicleCost;best=car.length>1?'${car[1]} • INR ${bestProfit.toStringAsFixed(2)}':id;}
    }return best;
  }
  String carName(String id){for(final r in cars){if(r.isNotEmpty&&r[0]==id)return r.length>1?r[1]:id;}return id;}
  Future<void> add()async{final value=double.tryParse(amount.text)??0;if(value<=0)return;await db.add('Expenses',[newId(),carId??'',category,value,DateTime.now().toIso8601String(),notes.text]);amount.clear();notes.clear();await load();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Expenses & Profit')),body:ListView(padding:const EdgeInsets.all(14),children:[
    Row(children:[Expanded(child:_moneyCard('Income',income,Colors.green)),Expanded(child:_moneyCard('Expenses',cost,Colors.red))]),
    Row(children:[Expanded(child:_moneyCard('Net Profit',income-cost,(income-cost)>=0?Colors.indigo:Colors.red)),Expanded(child:_moneyCard('Pending',pending,Colors.orange))]),
    Card(color:Theme.of(context).colorScheme.primaryContainer,child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('This month: INR ${(monthIncome-monthCost).toStringAsFixed(2)} profit',style:const TextStyle(fontWeight:FontWeight.bold)),
      Text('Income INR ${monthIncome.toStringAsFixed(2)} • Expenses INR ${monthCost.toStringAsFixed(2)}'),Text('Best-performing car: $bestCar'),
    ]))),const Divider(height:28),
    const Text('Add Expense',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:8),
    DropdownButtonFormField<String>(value:carId,isExpanded:true,decoration:const InputDecoration(labelText:'Vehicle (optional)',border:OutlineInputBorder()),
      items:cars.map((r)=>DropdownMenuItem(value:r[0],child:Text(r.length>1?r[1]:r[0]))).toList(),onChanged:(v)=>setState(()=>carId=v)),const SizedBox(height:8),
    DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'Category',border:OutlineInputBorder()),
      items:const ['Fuel','Maintenance','Insurance','EMI','Cleaning','Repair','Other'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v??'Other')),const SizedBox(height:8),
    field(amount,'Expense amount',number:true),field(notes,'Notes'),FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Record Expense')),
    const Divider(height:28),const Text('Expense History',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
    ...expenses.reversed.map((r)=>ListTile(leading:const Icon(Icons.money_off),title:Text('INR ${r.length>3?r[3]:'0'} • ${r.length>2?r[2]:''}'),subtitle:Text('${r.length>1&&r[1].isNotEmpty?carName(r[1]):'General'} • ${r.length>5?r[5]:''}'))),
  ]));
  Widget _moneyCard(String title,double value,Color color)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title),Text('INR ${value.toStringAsFixed(2)}',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:color))])));
}
