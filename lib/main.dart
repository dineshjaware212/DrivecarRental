import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:signature/signature.dart';
import 'package:url_launcher/url_launcher.dart';

part 'advanced_features.dart';

void main() => runApp(const DriveRentApp());

CellValue toCellValue(dynamic value) {
  if (value == null) return TextCellValue('');
  if (value is CellValue) return value;
  if (value is int) return IntCellValue(value);
  if (value is double) return DoubleCellValue(value);
  if (value is num) return DoubleCellValue(value.toDouble());
  if (value is bool) return BoolCellValue(value);
  if (value is DateTime) return DateTimeCellValue(
    year: value.year,
    month: value.month,
    day: value.day,
    hour: value.hour,
    minute: value.minute,
    second: value.second,
  );
  return TextCellValue(value.toString());
}

List<CellValue> toCellValues(List<dynamic> row) => row.map(toCellValue).toList();


class DriveRentApp extends StatelessWidget {
  const DriveRentApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GoCar Rental Services',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const DashboardPage(),
  );
}

class LocalExcelDb {
  static const sheets = ['Cars','Customers','Bookings','Payments','Maintenance','Settings','Inspections','Returns','Expenses'];
  static const headers = <String,List<String>>{
    'Inspections':['id','booking_id','type','odometer','fuel_percent','damage_notes','media_paths','signature_path','pdf_path','created_at'],
    'Returns':['id','booking_id','return_odometer','extra_km','extra_km_charge','late_hours','late_fee','fuel_charge','damage_charge','washing_charge','total_extra','created_at'],
    'Expenses':['id','car_id','category','amount','date','notes'],
  };

  Future<File> file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/DriveRent_Database.xlsx');
  }

  Future<void> ensure() async {
    final f = await file();
    if (await f.exists()) return;
    final e = Excel.createExcel();
    e.delete('Sheet1');
    e['Cars'].appendRow(toCellValues(['id','name','registration','daily_rate','status','odometer','photo_path','vehicle_type']));
    e['Customers'].appendRow(toCellValues(['id','name','phone','license_number','address','notes']));
    e['Bookings'].appendRow(toCellValues(['id','customer_id','car_id','pickup_at','return_at','amount','deposit','status','agreement_path','confirmation_status','confirmation_path','payment_status','daily_rate']));
    e['Payments'].appendRow(toCellValues(['id','booking_id','amount','method','paid_at','notes']));
    e['Maintenance'].appendRow(toCellValues(['id','car_id','description','status','scheduled_at','cost','notes']));
    e['Settings'].appendRow(toCellValues(['business_name','currency']));
    e['Settings'].appendRow(toCellValues(['GoCar Rental Services','INR']));
    await f.writeAsBytes(e.encode()!);
  }

  Future<Excel> open() async {
    await ensure();
    final f=await file();final e=Excel.decodeBytes(await f.readAsBytes());var changed=false;
    for(final entry in headers.entries){
      if(e[entry.key].rows.isEmpty){e[entry.key].appendRow(toCellValues(entry.value));changed=true;}
    }
    final requiredHeaders=<String,Map<int,String>>{
      'Cars':{7:'vehicle_type'},
      'Bookings':{12:'daily_rate'},
    };
    for(final sheetEntry in requiredHeaders.entries){
      for(final columnEntry in sheetEntry.value.entries){
        final cell=e[sheetEntry.key].cell(CellIndex.indexByColumnRow(
          columnIndex:columnEntry.key,rowIndex:0));
        if(cell.value?.toString()!=columnEntry.value){cell.value=TextCellValue(columnEntry.value);changed=true;}
      }
    }
    if(changed)await f.writeAsBytes(e.encode()!);
    return e;
  }

  Future<void> save(Excel e) async => (await file()).writeAsBytes(e.encode()!);

  Future<List<List<String>>> rows(String sheet) async {
    final e = await open();
    return e[sheet].rows.skip(1)
      .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
      .where((r) => r.any((x) => x.isNotEmpty)).toList();
  }

  Future<void> add(String sheet, List<dynamic> row) async {
    final e = await open(); e[sheet].appendRow(toCellValues(row)); await save(e);
  }

  Future<void> deleteById(String sheet, String id) async {
    final e = await open(); final sh = e[sheet];
    for (var i = 1; i < sh.rows.length; i++) {
      if (sh.rows[i].isNotEmpty && sh.rows[i][0]?.value?.toString() == id) {
        sh.removeRow(i); break;
      }
    }
    await save(e);
  }

  Future<void> setValueById(String sheet, String id, int column, dynamic value, {String? header}) async {
    final e = await open();
    final sh = e[sheet];
    if (header != null) sh.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0)).value = toCellValue(header);
    for (var i = 1; i < sh.rows.length; i++) {
      if (sh.rows[i].isNotEmpty && sh.rows[i][0]?.value?.toString() == id) {
        sh.cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: i)).value = toCellValue(value);
        break;
      }
    }
    await save(e);
  }

  Future<void> importExcel() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx']);
    if (r?.files.single.path != null) {
      await (await file()).writeAsBytes(
        await File(r!.files.single.path!).readAsBytes());
    }
  }

  Future<void> exportExcel() async =>
    Share.shareXFiles([XFile((await file()).path)],
      text: 'GoCar Rental Services Excel backup');
}

final db = LocalExcelDb();
String newId() => DateTime.now().microsecondsSinceEpoch.toString();
String shortBookingId(String value) => value.length > 6 ? value.substring(value.length - 6) : value;

const agreementTerms = <String>[
  '1. Mileage Limit: The daily mileage limit is 350 km. Additional kilometres will be charged at INR 5 per km for a 5-seater vehicle and INR 7 per km for a 7-seater vehicle.',
  '2. Late Return: A late-return fee of INR 200 per hour will apply. If the vehicle is returned more than three hours late, an additional full day\'s rental charge will apply.',
  '3. Security Deposit: A bike, scooter, or laptop must be provided as the security deposit.',
  '4. Advance Payment and Speed Limit: The advance payment is non-refundable. The maximum permitted speed is 100 km/h.',
  '5. Vehicle Condition and Damage: The customer is responsible for tyre punctures, a discharged battery caused by using the air conditioner while the engine is off or leaving the lights on, dents, long scratches, accidents, and any other damage caused during the rental period. Insurance coverage will not apply to such damage, and the customer must pay 100% of the repair costs.',
  '6. Alcohol Policy: Drinking and driving is strictly prohibited. A penalty of INR 10,000 will apply.',
  '7. Toll and Fuel Charges: Toll and fuel charges are not included in the rental price. Any additional fuel or toll balance purchased by the customer is non-refundable. A QR code is provided behind the rear-view mirror for checking or recharging the FASTag balance.',
  '8. Mumbai-Pune Expressway Rules: A fine of INR 2,000 will apply if the vehicle exceeds 100 km/h. A fine of INR 1,000 will apply if either front-seat passenger is not wearing a seat belt. Because the expressway has multiple enforcement cameras, customers who exceed 100 km/h must leave an additional deposit of INR 3,000 for three months to cover any delayed camera-issued fines.',
  '9. Vehicle Cleanliness: The vehicle must be returned clean. Otherwise, applicable washing charges will be added.',
  'By renting the vehicle and signing this agreement, the customer confirms that they have read, understood, and agreed to comply with all the above terms and conditions.',
];

class AgreementService {
  static String safeName(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'Customer' : cleaned;
  }

  static Future<File> build({
    required List<String> booking,
    required String customerName,
    required String customerPhone,
    required String licenceNumber,
    required String carName,
    required String registration,
    required Uint8List signature,
  }) async {
    String cell(int index) => booking.length > index ? booking[index] : '';
    String date(String value) {
      final parsed = DateTime.tryParse(value);
      return parsed == null ? value : DateFormat('dd MMM yyyy').format(parsed);
    }

    final pdf = pw.Document();
    final signedAt = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final signatureImage = pw.MemoryImage(signature);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => [
        pw.Center(child: pw.Text('SELF-DRIVE VEHICLE RENTAL AGREEMENT',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 6),
        pw.Center(child: pw.Text('GoCar Rental Services',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
        pw.SizedBox(height: 22),
        _pdfSection('Agreement details', [
          ['Agreement / Booking ID', cell(0)],
          ['Created and signed', signedAt],
          ['Status', cell(7)],
        ]),
        _pdfSection('Customer details', [
          ['Customer name', customerName],
          ['Phone', customerPhone],
          ['Driving licence', licenceNumber],
        ]),
        _pdfSection('Vehicle and rental details', [
          ['Vehicle', carName],
          ['Registration', registration],
          ['Pickup date', date(cell(3))],
          ['Return date', date(cell(4))],
          ['Daily rent', 'INR ${cell(12)}'],
          ['Rental amount', 'INR ${cell(5)}'],
          ['Security deposit', 'INR ${cell(6)}'],
        ]),
        pw.SizedBox(height: 10),
        pw.Text('Terms and conditions', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...agreementTerms.map((term) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('•  '), pw.Expanded(child: pw.Text(term, style: const pw.TextStyle(fontSize: 10))),
          ]))),
        pw.SizedBox(height: 24),
        pw.Text('Customer signature', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Container(
          width: 220, height: 90, margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
          child: pw.Image(signatureImage, fit: pw.BoxFit.contain)),
        pw.SizedBox(height: 4),
        pw.Text(customerName, style: const pw.TextStyle(fontSize: 10)),
      ],
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
    ));

    final root = await getApplicationDocumentsDirectory();
    final agreements = Directory('${root.path}/agreements');
    await agreements.create(recursive: true);
    final shortId = cell(0).length > 8 ? cell(0).substring(cell(0).length - 8) : cell(0);
    final file = File('${agreements.path}/Rental_Agreement_${safeName(customerName)}_$shortId.pdf');
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  static pw.Widget _pdfSection(String title, List<List<String>> rows) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        data: rows,
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerCount: 0,
        cellPadding: const pw.EdgeInsets.all(6),
        columnWidths: {0: const pw.FixedColumnWidth(145)},
        border: pw.TableBorder.all(color: PdfColors.grey300),
      ),
      pw.SizedBox(height: 14),
    ]);
}

class CatalogService {
  static Future<File> build(List<List<String>> cars) async {
    final pdf=pw.Document();
    final widgets=<pw.Widget>[
      pw.Text('AVAILABLE RENTAL VEHICLES',style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),
      pw.SizedBox(height:6),pw.Text('GoCar Rental Services • ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
      pw.SizedBox(height:18),
    ];
    for(final car in cars){
      pw.Widget? photo;
      if(car.length>6&&car[6].isNotEmpty){
        final f=File(car[6]);if(await f.exists())photo=pw.Image(pw.MemoryImage(await f.readAsBytes()),width:150,height:90,fit:pw.BoxFit.cover);
      }
      widgets.add(pw.Container(
        margin:const pw.EdgeInsets.only(bottom:12),padding:const pw.EdgeInsets.all(10),
        decoration:pw.BoxDecoration(border:pw.Border.all(color:PdfColors.grey300),borderRadius:pw.BorderRadius.circular(6)),
        child:pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
          if(photo!=null)...[photo,pw.SizedBox(width:12)],
          pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
            pw.Text(car.length>1?car[1]:'Car',style:pw.TextStyle(fontSize:15,fontWeight:pw.FontWeight.bold)),
            pw.Text('Type: ${car.length>7?car[7]:'Car'}'),
            pw.Text('Registration: ${car.length>2?car[2]:''}'),
            pw.Text('Daily rate: INR ${car.length>3?car[3]:'0'}'),
            pw.Text('Status: Available',style:pw.TextStyle(color:PdfColors.green700)),
          ])),
        ])));
    }
    if(cars.isEmpty)widgets.add(pw.Text('No vehicles are currently available.'));
    pdf.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(32),build:(_)=>widgets));
    final dir=await getApplicationDocumentsDirectory();
    final file=File('${dir.path}/DriveRent_Available_Vehicles_Catalog.pdf');
    await file.writeAsBytes(await pdf.save(),flush:true);return file;
  }
}

class BookingConfirmationService {
  static Future<File> build({required List<String> booking,required String customer,
    required String phone,required String car})async{
    String cell(int i)=>booking.length>i?booking[i]:'';
    String date(String value){final d=DateTime.tryParse(value);return d==null?value:DateFormat('dd MMM yyyy').format(d);}
    final qrData='DRIVERENT|BOOKING=${cell(0)}|CUSTOMER=$customer|CAR=$car|PICKUP=${cell(3)}|RETURN=${cell(4)}|AMOUNT=${cell(5)}';
    final paymentQrData=await rootBundle.load('assets/payment_qr.png');
    final paymentQr=pw.MemoryImage(paymentQrData.buffer.asUint8List(
      paymentQrData.offsetInBytes,paymentQrData.lengthInBytes));
    final pdf=pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(40),build:(_)=>[
        pw.Center(child:pw.Text('BOOKING CONFIRMATION',style:pw.TextStyle(fontSize:21,fontWeight:pw.FontWeight.bold))),
        pw.SizedBox(height:22),
        AgreementService._pdfSection('Booking details',[
          ['Booking ID',cell(0)],['Customer',customer],['Phone',phone],['Vehicle',car],
          ['Pickup',date(cell(3))],['Return',date(cell(4))],['Daily rent','INR ${cell(12)}'],['Rental amount','INR ${cell(5)}'],
          ['Security deposit','INR ${cell(6)}'],['Confirmation status','Confirmed'],
        ]),
        pw.Center(child:pw.BarcodeWidget(barcode:pw.Barcode.qrCode(),data:qrData,width:150,height:150)),
        pw.SizedBox(height:10),
        pw.Center(child:pw.Text('Scan this QR code to verify the booking details.',style:const pw.TextStyle(fontSize:10))),
        pw.SizedBox(height:24),
        pw.Center(child:pw.Text('PAYMENT QR CODE',style:pw.TextStyle(fontSize:16,fontWeight:pw.FontWeight.bold))),
        pw.SizedBox(height:8),
        pw.Center(child:pw.Image(paymentQr,width:230,height:300,fit:pw.BoxFit.contain)),
        pw.Center(child:pw.Text('UPI ID: dineshjaware212@okhdfcbank',style:const pw.TextStyle(fontSize:10))),
      ]));
    final dir=await getApplicationDocumentsDirectory();final confirmations=Directory('${dir.path}/confirmations');
    await confirmations.create(recursive:true);
    final file=File('${confirmations.path}/Booking_Confirmation_${shortBookingId(cell(0))}.pdf');
    await file.writeAsBytes(await pdf.save(),flush:true);return file;
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  int tab = 0;
  @override
  Widget build(BuildContext c) {
    final pages = [
      HomePage(onNavigate:(index)=>setState(()=>tab=index)),
      const CarsPage(),const CustomersPage(),const BookingsPage(),const PaymentsPage(),const MaintenancePage()
    ];
    return Scaffold(
    appBar: AppBar(title: const Text('GoCar Rental Services'),actions:[
      IconButton(tooltip:'Operations',icon:const Icon(Icons.grid_view_rounded),
        onPressed:()=>Navigator.of(c).push(MaterialPageRoute(builder:(_)=>const OperationsHubPage()))),
      IconButton(tooltip:'Available Vehicles Catalog',icon:const Icon(Icons.photo_library_outlined),
        onPressed:()=>Navigator.of(c).push(MaterialPageRoute(builder:(_)=>const CatalogPage())))
    ]),
    body: pages[tab],
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.directions_car), label: 'Vehicles'),
        NavigationDestination(icon: Icon(Icons.people), label: 'Customers'),
        NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Bookings'),
        NavigationDestination(icon: Icon(Icons.payments), label: 'Payments'),
        NavigationDestination(icon: Icon(Icons.build), label: 'Service'),
      ],
    ),
  );}
}

class HomePage extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  const HomePage({super.key,required this.onNavigate});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  Map<String,int> n = {};
  double collected=0,outstanding=0;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final m = <String,int>{};
    for (final s in LocalExcelDb.sheets.take(5)) m[s] = (await db.rows(s)).length;
    final vehicles=await db.rows('Cars');
    m['Cars']=vehicles.where((r)=>r.length<=7||r[7]!='Two Wheeler').length;
    m['TwoWheelers']=vehicles.where((r)=>r.length>7&&r[7]=='Two Wheeler').length;
    final bookingRows=await db.rows('Bookings');
    final paymentRows=await db.rows('Payments');
    final total=bookingRows.fold<double>(0.0,(sum,r)=>sum+(r.length>5?double.tryParse(r[5])??0:0));
    final paid=paymentRows.fold<double>(0.0,(sum,r)=>sum+(r.length>2?double.tryParse(r[2])??0:0));
    if (mounted) setState(() {n=m;collected=paid;outstanding=(total-paid)<0?0:total-paid;});
  }
  @override
  Widget build(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Rental Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        metric('Cars', n['Cars'] ?? 0, Icons.directions_car,1),
        metric('Two Wheelers', n['TwoWheelers'] ?? 0, Icons.two_wheeler,1),
        metric('Customers', n['Customers'] ?? 0, Icons.people,2),
        metric('Bookings', n['Bookings'] ?? 0, Icons.calendar_month,3),
        metric('Payments', n['Payments'] ?? 0, Icons.payments,4),
        metric('Service', n['Maintenance'] ?? 0, Icons.build,5),
      ]),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:Card(color:Colors.green.shade50,child:Padding(padding:const EdgeInsets.all(14),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Collected'),Text('INR ${collected.toStringAsFixed(2)}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))])))),
        Expanded(child:Card(color:Colors.orange.shade50,child:Padding(padding:const EdgeInsets.all(14),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Outstanding'),Text('INR ${outstanding.toStringAsFixed(2)}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))])))),
      ]),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () async { await db.importExcel(); await load(); },
        icon: const Icon(Icons.upload_file), label: const Text('Import Excel')),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: db.exportExcel,
        icon: const Icon(Icons.download), label: const Text('Backup / Share Excel')),
    ]),
  );
  Widget metric(String t, int v, IconData i,int destination) => SizedBox(
    width: 155, child: Card(child: InkWell(borderRadius:BorderRadius.circular(12),
      onTap:()=>widget.onNavigate(destination),
      child:Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [Icon(i,size:30), Text('$v',style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold)), Text(t)])))));
}

class CarsPage extends StatefulWidget {
  const CarsPage({super.key});
  @override State<CarsPage> createState() => _CarsPageState();
}
class _CarsPageState extends State<CarsPage> {
  List<List<String>> data=[]; final name=TextEditingController(), reg=TextEditingController(), rate=TextEditingController();
  String vehicleType='Car';
  @override void initState(){super.initState();load();}
  Future<void> load()async{data=await db.rows('Cars');if(mounted)setState((){});}
  Future<void> add()async{
    if(name.text.trim().isEmpty||reg.text.trim().isEmpty)return;
    await db.add('Cars',[newId(),name.text.trim(),reg.text.trim(),double.tryParse(rate.text)??0,'Available',0,'',vehicleType]);
    name.clear();reg.clear();rate.clear();load();
  }
  Future<void> remove(String x)async{await db.deleteById('Cars',x);load();}
  Future<void> uploadPhoto(List<String> car)async{
    final picked=await FilePicker.platform.pickFiles(type:FileType.image);
    final source=picked?.files.single.path;if(source==null)return;
    final dir=await getApplicationDocumentsDirectory();final photos=Directory('${dir.path}/car_photos');
    await photos.create(recursive:true);
    final ext=source.contains('.')?source.substring(source.lastIndexOf('.')):'.jpg';
    final target=File('${photos.path}/car_${car[0]}$ext');await File(source).copy(target.path);
    await db.setValueById('Cars',car[0],6,target.path,header:'photo_path');await load();
  }
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    const Text('Vehicles',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
    DropdownButtonFormField<String>(value:vehicleType,decoration:const InputDecoration(labelText:'Vehicle type',border:OutlineInputBorder()),
      items:const ['Car','Two Wheeler'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>vehicleType=v??'Car')),
    const SizedBox(height:8),field(name,'Vehicle name / model'),field(reg,'Registration'),field(rate,'Default daily rate (INR)',number:true),
    FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Add Vehicle')),
    ...data.map((r)=>Card(child:ListTile(
      leading:r.length>6&&r[6].isNotEmpty&&File(r[6]).existsSync()
        ?ClipRRect(borderRadius:BorderRadius.circular(6),child:Image.file(File(r[6]),width:58,height:58,fit:BoxFit.cover))
        :SizedBox(width:58,child:Icon(r.length>7&&r[7]=='Two Wheeler'?Icons.two_wheeler:Icons.directions_car)),
      title:Text(r.length>1?r[1]:''),
      subtitle:Text('${r.length>7?r[7]:'Car'} • ${r.length>2?r[2]:''} • ₹${r.length>3?r[3]:''}/day • ${r.length>4?r[4]:''}'),
      trailing:PopupMenuButton<String>(onSelected:(v)=>v=='photo'?uploadPhoto(r):remove(r[0]),itemBuilder:(_)=>const[
        PopupMenuItem(value:'photo',child:ListTile(leading:Icon(Icons.add_a_photo),title:Text('Upload photo'))),
        PopupMenuItem(value:'delete',child:ListTile(leading:Icon(Icons.delete_outline),title:Text('Delete vehicle'))),
      ]))))
  ]);
}

class CatalogPage extends StatefulWidget{
  const CatalogPage({super.key});
  @override State<CatalogPage> createState()=>_CatalogPageState();
}
class _CatalogPageState extends State<CatalogPage>{
  List<List<String>> cars=[],bookings=[];bool busy=false;
  @override void initState(){super.initState();load();}
  bool available(List<String> car){
    final now=DateTime.now();
    return !bookings.any((b){
      if(b.length<5||b[2]!=car[0]||(b.length>7&&b[7]=='Cancelled'))return false;
      final start=DateTime.tryParse(b[3]),end=DateTime.tryParse(b[4]);
      return start!=null&&end!=null&&!now.isBefore(start)&&now.isBefore(end);
    });
  }
  List<List<String>> get availableCars=>cars.where(available).toList();
  Future<void> load()async{cars=await db.rows('Cars');bookings=await db.rows('Bookings');if(mounted)setState((){});}
  Future<void> shareCatalog()async{
    setState(()=>busy=true);
    try{final file=await CatalogService.build(availableCars);await Share.shareXFiles([XFile(file.path)],
      subject:'Available rental vehicles',text:'Our currently available cars and two-wheelers. Select WhatsApp to share this catalog.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Available Vehicles Catalog')),
    floatingActionButton:FloatingActionButton.extended(onPressed:busy?null:shareCatalog,
      icon:const Icon(Icons.share),label:const Text('Share via WhatsApp')),
    body:availableCars.isEmpty?const Center(child:Text('No vehicles are currently available.')):
      GridView.builder(padding:const EdgeInsets.fromLTRB(12,12,12,90),
        gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:.72,crossAxisSpacing:10,mainAxisSpacing:10),
        itemCount:availableCars.length,itemBuilder:(_,i){final r=availableCars[i];
          final hasPhoto=r.length>6&&r[6].isNotEmpty&&File(r[6]).existsSync();
          return Card(clipBehavior:Clip.antiAlias,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Expanded(child:SizedBox(width:double.infinity,child:hasPhoto?Image.file(File(r[6]),fit:BoxFit.cover):
              Container(color:Colors.grey.shade200,child:Icon(r.length>7&&r[7]=='Two Wheeler'?Icons.two_wheeler:Icons.directions_car,size:64)))),
            Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(r.length>1?r[1]:'Car',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold)),
              Text('${r.length>7?r[7]:'Car'} • ${r.length>2?r[2]:''}'),Text('INR ${r.length>3?r[3]:'0'} / day'),
              const Text('Available',style:TextStyle(color:Colors.green,fontWeight:FontWeight.bold)),
            ]))]));}));
}

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override State<CustomersPage> createState()=>_CustomersPageState();
}
class _CustomersPageState extends State<CustomersPage>{
  List<List<String>> data=[]; final name=TextEditingController(),phone=TextEditingController(),lic=TextEditingController();
  @override void initState(){super.initState();load();}
  Future<void> load()async{data=await db.rows('Customers');if(mounted)setState((){});}
  Future<void> add()async{
    if(name.text.trim().isEmpty)return;
    await db.add('Customers',[newId(),name.text.trim(),phone.text.trim(),lic.text.trim(),'','']);
    name.clear();phone.clear();lic.clear();load();
  }
  Future<void> remove(String x)async{await db.deleteById('Customers',x);load();}
  Future<void> selectFromContacts()async{
    try{
      if(!await FlutterContacts.requestPermission(readonly:true)){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('Contacts permission is required. Please allow it in phone settings.')));
        return;
      }
      final selected=await FlutterContacts.openExternalPick();
      if(selected==null)return;
      final contact=await FlutterContacts.getContact(selected.id,withProperties:true)??selected;
      final selectedName=contact.displayName.trim();
      final selectedPhone=contact.phones.isEmpty?'':contact.phones.first.number.trim();
      if(selectedName.isEmpty||selectedPhone.isEmpty){
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('The selected contact must have a name and phone number.')));
        return;
      }
      await db.add('Customers',[newId(),selectedName,selectedPhone,'','','']);
      await load();
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('$selectedName added as a customer.')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text('Unable to open phone contacts: $e')));
    }
  }
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    const Text('Customers',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
    OutlinedButton.icon(onPressed:selectFromContacts,
      icon:const Icon(Icons.contact_phone),label:const Text('Select Contact & Add Customer')),
    const SizedBox(height:8),
    field(name,'Customer name'),field(phone,'Phone',number:true),field(lic,'Driving licence number'),
    FilledButton.icon(onPressed:add,icon:const Icon(Icons.person_add),label:const Text('Add Customer')),
    ...data.map((r)=>Card(child:ListTile(
      leading:const Icon(Icons.person), title:Text(r.length>1?r[1]:''),
      subtitle:Text('${r.length>2?r[2]:''} • DL: ${r.length>3?r[3]:''}'),
      trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>remove(r[0])))))
  ]);
}

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});
  @override State<BookingsPage> createState()=>_BookingsPageState();
}
class _BookingsPageState extends State<BookingsPage>{
  List<List<String>> data=[],customers=[],cars=[],payments=[];
  final amount=TextEditingController(),deposit=TextEditingController(),bookingRate=TextEditingController();
  String? selectedCustomerId,selectedCarId;
  DateTime pickup=DateTime.now(), ret=DateTime.now().add(const Duration(days:1));
  @override void initState(){super.initState();load();}
  int get rentalDays {final d=ret.difference(pickup).inDays;return d<1?1:d;}
  double get defaultDailyRate {
    for(final r in cars){if(r.isNotEmpty&&r[0]==selectedCarId)return r.length>3?double.tryParse(r[3])??0:0;}
    return 0;
  }
  double get dailyRate=>double.tryParse(bookingRate.text)??defaultDailyRate;
  String customerLabel(String id){for(final r in customers){if(r.isNotEmpty&&r[0]==id)return r.length>1?r[1]:id;}return id;}
  String customerPhone(String id){for(final r in customers){if(r.isNotEmpty&&r[0]==id)return r.length>2?r[2]:'';}return '';}
  String documentStatus(String id){
    for(final r in customers){if(r.isNotEmpty&&r[0]==id){var count=0;for(final column in [6,7,8]){if(r.length>column&&r[column].isNotEmpty)count++;}return '$count/3 documents';}}
    return '0/3 documents';
  }
  String carLabel(String id){for(final r in cars){if(r.isNotEmpty&&r[0]==id){final type=r.length>7?r[7]:'Car';return r.length>2?'$type • ${r[1]} (${r[2]})':'$type • ${r[1]}';}}return id;}
  double paidFor(String id)=>payments.where((r)=>r.length>2&&r[1]==id)
    .fold<double>(0.0,(sum,r)=>sum+(double.tryParse(r[2])??0));
  void recalculate(){amount.text=(rentalDays*dailyRate).toStringAsFixed(2);}
  Future<void> load()async{
    data=await db.rows('Bookings');customers=await db.rows('Customers');
    cars=await db.rows('Cars');payments=await db.rows('Payments');
    if(mounted)setState((){});
  }
  Future<void> pick(bool isPickup)async{
    final d=await showDatePicker(context:context,initialDate:isPickup?pickup:ret,firstDate:DateTime(2020),lastDate:DateTime(2100));
    if(d!=null){
      setState((){
        if(isPickup){pickup=d;if(!ret.isAfter(pickup))ret=pickup.add(const Duration(days:1));}
        else if(d.isAfter(pickup)){ret=d;}
        recalculate();
      });
    }
  }
  Future<void> add()async{
    if(selectedCustomerId==null||selectedCarId==null){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Select a customer and a vehicle.')));return;
    }
    final overlaps=data.any((r){
      if(r.length<5||r[2]!=selectedCarId)return false;
      final oldStart=DateTime.tryParse(r[3]),oldEnd=DateTime.tryParse(r[4]);
      return oldStart!=null&&oldEnd!=null&&pickup.isBefore(oldEnd)&&ret.isAfter(oldStart);
    });
    if(overlaps){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('This vehicle is already booked during the selected dates.')));return;
    }
    recalculate();
    await db.add('Bookings',[newId(),selectedCustomerId,selectedCarId,pickup.toIso8601String(),ret.toIso8601String(),
      double.tryParse(amount.text)??0,double.tryParse(deposit.text)??0,'Booked','','','','Pending',dailyRate]);
    selectedCustomerId=null;selectedCarId=null;amount.clear();deposit.clear();bookingRate.clear();load();
  }
  Future<File> confirmationFile(List<String> booking)async{
    if(booking.length>10&&booking[10].isNotEmpty){final existing=File(booking[10]);if(await existing.exists())return existing;}
    final customerId=booking.length>1?booking[1]:'';final carId=booking.length>2?booking[2]:'';
    final file=await BookingConfirmationService.build(booking:booking,customer:customerLabel(customerId),
      phone:customerPhone(customerId),car:carLabel(carId));
    await db.setValueById('Bookings',booking[0],9,'Confirmed',header:'confirmation_status');
    await db.setValueById('Bookings',booking[0],10,file.path,header:'confirmation_path');
    return file;
  }
  Future<void> confirmAndMessage(List<String> booking)async{
    await confirmationFile(booking);
    final customerId=booking.length>1?booking[1]:'';var phone=customerPhone(customerId).replaceAll(RegExp(r'[^0-9]'),'');
    if(phone.length==10)phone='91$phone';
    if(phone.isEmpty){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Add the customer phone number before sending confirmation.')));return;
    }
    String displayDate(String value){final d=DateTime.tryParse(value);return d==null?value:DateFormat('dd MMM yyyy').format(d);}
    final message='Booking Confirmed!\n\nBooking ID: ${booking[0]}\nCustomer: ${customerLabel(customerId)}\nVehicle: ${carLabel(booking.length>2?booking[2]:'')}\nPickup: ${booking.length>3?displayDate(booking[3]):''}\nReturn: ${booking.length>4?displayDate(booking[4]):''}\nDaily Rent: INR ${booking.length>12?booking[12]:''}\nRental Amount: INR ${booking.length>5?booking[5]:''}\n\nThank you for choosing GoCar Rental Services.';
    final uri=Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)&&mounted){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('WhatsApp could not be opened.')));
    }
    await load();
  }
  Future<void> shareConfirmation(List<String> booking)async{
    final file=await confirmationFile(booking);
    await Share.shareXFiles([XFile(file.path)],subject:'GoCar Rental Services booking confirmation',
      text:'QR-coded booking confirmation for ${customerLabel(booking.length>1?booking[1]:'')}. Select WhatsApp to send it.');
    await load();
  }
  Future<void> remove(String x)async{await db.deleteById('Bookings',x);load();}
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    const Text('Bookings',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
    DropdownButtonFormField<String>(value:selectedCustomerId,isExpanded:true,
      decoration:const InputDecoration(labelText:'Select customer',border:OutlineInputBorder()),
      items:customers.map((r)=>DropdownMenuItem(value:r[0],child:Text(r.length>2?'${r[1]} • ${r[2]}':r[1]))).toList(),
      onChanged:(v)=>setState(()=>selectedCustomerId=v)),
    const SizedBox(height:8),
    DropdownButtonFormField<String>(value:selectedCarId,isExpanded:true,
      decoration:const InputDecoration(labelText:'Select vehicle',border:OutlineInputBorder()),
      items:cars.map((r)=>DropdownMenuItem(value:r[0],child:Text('${carLabel(r[0])} • INR ${r.length>3?r[3]:'0'}/day'))).toList(),
      onChanged:(v)=>setState((){selectedCarId=v;bookingRate.text=defaultDailyRate.toStringAsFixed(2);recalculate();})),
    const SizedBox(height:8),
    TextField(controller:bookingRate,keyboardType:const TextInputType.numberWithOptions(decimal:true),
      decoration:const InputDecoration(labelText:'Daily rent for this booking (INR)',border:OutlineInputBorder()),
      onChanged:(_)=>setState(recalculate)),
    const SizedBox(height:8),
    Row(children:[Expanded(child:Text('Pickup: ${DateFormat('dd MMM yyyy').format(pickup)}')),TextButton(onPressed:()=>pick(true),child:const Text('Change'))]),
    Row(children:[Expanded(child:Text('Return: ${DateFormat('dd MMM yyyy').format(ret)}')),TextButton(onPressed:()=>pick(false),child:const Text('Change'))]),
    Card(color:Theme.of(context).colorScheme.primaryContainer,child:Padding(
      padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('$rentalDays rental day${rentalDays==1?'':'s'} × INR ${dailyRate.toStringAsFixed(2)}'),
        const SizedBox(height:4),
        Text('Rental total: INR ${amount.text.isEmpty?'0.00':amount.text}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
      ]))),
    field(deposit,'Security deposit value (INR)',number:true),
    FilledButton.icon(onPressed:add,icon:const Icon(Icons.event_available),label:const Text('Create Booking')),
    ...data.map((r)=>Card(child:ListTile(
      title:Text('Booking ${shortBookingId(r[0])}'),
      subtitle:Builder(builder:(_){
        final total=r.length>5?double.tryParse(r[5])??0:0;
        final paid=paidFor(r[0]);final due=(total-paid)<0?0:total-paid;
        final workflow=r.length>7?r[7]:'Booked';final payment=r.length>11?r[11]:(due<=0?'Paid':paid>0?'Partially Paid':'Pending');
        final rate=r.length>12?r[12]:'';
        return Text('${customerLabel(r.length>1?r[1]:'')} • ${carLabel(r.length>2?r[2]:'')}\n$workflow • Payment: $payment${rate.isEmpty?'':' • INR $rate/day'} • ${documentStatus(r.length>1?r[1]:'')}\nTotal: INR ${total.toStringAsFixed(2)} • Paid: INR ${paid.toStringAsFixed(2)} • Due: INR ${due.toStringAsFixed(2)}');}),
      isThreeLine:true,
      trailing:PopupMenuButton<String>(
        onSelected:(value){
          if(value=='agreement'){
            Navigator.of(context).push(MaterialPageRoute(
              builder:(_)=>AgreementPage(booking:r)));
          }else if(value=='confirm'){
            confirmAndMessage(r);
          }else if(value=='share_confirmation'){
            shareConfirmation(r);
          }else if(value=='invoice'){
            shareBookingInvoice(r,customers,cars,payments);
          }else if(value=='return'){
            Navigator.of(context).push(MaterialPageRoute(builder:(_)=>ReturnChargesPage(booking:r))).then((_)=>load());
          }else if(value=='status'){
            showBookingStatusDialog(context,r,load);
          }else if(value=='messages'){
            Navigator.of(context).push(MaterialPageRoute(builder:(_)=>WhatsAppTemplatesPage(
              booking:r,customerName:customerLabel(r.length>1?r[1]:''),
              customerPhone:customerPhone(r.length>1?r[1]:''),carName:carLabel(r.length>2?r[2]:''))));
          }else if(value=='documents'){
            Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CustomerDocumentsPage(
              initialCustomerId:r.length>1?r[1]:null)));
          }else if(value=='delete'){
            remove(r[0]);
          }
        },
        itemBuilder:(_)=>const [
          PopupMenuItem(value:'agreement',child:ListTile(
            leading:Icon(Icons.draw),title:Text('Create agreement'))),
          PopupMenuItem(value:'confirm',child:ListTile(
            leading:Icon(Icons.verified),title:Text('Confirm & message customer'))),
          PopupMenuItem(value:'share_confirmation',child:ListTile(
            leading:Icon(Icons.qr_code_2),title:Text('Share QR confirmation'))),
          PopupMenuItem(value:'invoice',child:ListTile(
            leading:Icon(Icons.receipt_long),title:Text('Share invoice / receipt'))),
          PopupMenuItem(value:'return',child:ListTile(
            leading:Icon(Icons.assignment_return),title:Text('Return & extra charges'))),
          PopupMenuItem(value:'status',child:ListTile(
            leading:Icon(Icons.sync_alt),title:Text('Change booking status'))),
          PopupMenuItem(value:'messages',child:ListTile(
            leading:Icon(Icons.message),title:Text('WhatsApp templates'))),
          PopupMenuItem(value:'documents',child:ListTile(
            leading:Icon(Icons.badge),title:Text('Customer documents'))),
          PopupMenuItem(value:'delete',child:ListTile(
            leading:Icon(Icons.delete_outline),title:Text('Delete booking'))),
        ],
      ))))
  ]);

  @override void dispose(){amount.dispose();deposit.dispose();bookingRate.dispose();super.dispose();}
}

class AgreementPage extends StatefulWidget {
  final List<String> booking;
  const AgreementPage({super.key, required this.booking});
  @override State<AgreementPage> createState()=>_AgreementPageState();
}

class _AgreementPageState extends State<AgreementPage> {
  final customerName=TextEditingController();
  final customerPhone=TextEditingController();
  final licenceNumber=TextEditingController();
  final carName=TextEditingController();
  final registration=TextEditingController();
  final signature=SignatureController(penStrokeWidth:3,penColor:Colors.indigo);
  File? agreement;
  bool busy=false;
  bool accepted=false;

  @override void initState(){
    super.initState();
    if(widget.booking.length>8&&widget.booking[8].isNotEmpty){
      final existing=File(widget.booking[8]);
      if(existing.existsSync())agreement=existing;
    }
    loadDetails();
  }

  Future<void> loadDetails()async{
    final customerValue=widget.booking.length>1?widget.booking[1]:'';
    final carValue=widget.booking.length>2?widget.booking[2]:'';
    customerName.text=customerValue;
    carName.text=carValue;
    final customers=await db.rows('Customers');
    final cars=await db.rows('Cars');
    List<String>? customer;
    List<String>? car;
    for(final row in customers){if(row.isNotEmpty&&row[0]==customerValue){customer=row;break;}}
    for(final row in cars){if(row.isNotEmpty&&row[0]==carValue){car=row;break;}}
    if(customer!=null){
      if(customer.length>1)customerName.text=customer[1];
      if(customer.length>2)customerPhone.text=customer[2];
      if(customer.length>3)licenceNumber.text=customer[3];
    }
    if(car!=null){
      if(car.length>1)carName.text=car[1];
      if(car.length>2)registration.text=car[2];
    }
    if(mounted)setState((){});
  }

  Future<void> generate()async{
    if(customerName.text.trim().isEmpty||carName.text.trim().isEmpty){
      message('Enter the customer and vehicle details.');return;
    }
    if(signature.isEmpty){message('Ask the customer to sign first.');return;}
    if(!accepted){message('The customer must accept the terms and conditions.');return;}
    setState(()=>busy=true);
    try{
      final png=await signature.toPngBytes();
      if(png==null)throw Exception('Signature could not be captured');
      agreement=await AgreementService.build(
        booking:widget.booking,
        customerName:customerName.text.trim(),
        customerPhone:customerPhone.text.trim(),
        licenceNumber:licenceNumber.text.trim(),
        carName:carName.text.trim(),
        registration:registration.text.trim(),
        signature:png,
      );
      await db.setValueById('Bookings',widget.booking[0],8,agreement!.path,header:'agreement_path');
      message('Signed agreement created successfully.');
    }catch(e){message('Could not create agreement: $e');}
    finally{if(mounted)setState(()=>busy=false);}
  }

  Future<File?> readyFile()async{
    if(agreement==null)await generate();
    return agreement;
  }

  Future<void> download()async{
    final file=await readyFile();
    if(file==null)return;
    try{
      final saved=await FilePicker.platform.saveFile(
        dialogTitle:'Download rental agreement',
        fileName:file.path.split(Platform.pathSeparator).last,
        type:FileType.custom,
        allowedExtensions:['pdf'],
        bytes:await file.readAsBytes(),
      );
      if(saved!=null)message('Agreement downloaded.');
    }catch(e){message('Could not download agreement: $e');}
  }

  Future<void> shareWhatsApp()async{
    final file=await readyFile();
    if(file==null)return;
    await Share.shareXFiles([XFile(file.path)],
      subject:'Signed rental agreement',
      text:'Signed rental agreement for ${customerName.text.trim()}. Select WhatsApp to send it.');
  }

  void message(String text){
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  }

  @override void dispose(){
    customerName.dispose();customerPhone.dispose();licenceNumber.dispose();
    carName.dispose();registration.dispose();signature.dispose();super.dispose();
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Rental Agreement')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Text('Booking ${shortBookingId(widget.booking[0])}',
        style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:12),
      field(customerName,'Customer name'),
      field(customerPhone,'Customer phone',number:true),
      field(licenceNumber,'Driving licence number'),
      field(carName,'Vehicle name'),
      field(registration,'Registration number'),
      const SizedBox(height:8),
      ExpansionTile(
        tilePadding:EdgeInsets.zero,
        title:const Text('View Terms and Conditions',style:TextStyle(fontWeight:FontWeight.bold)),
        children:agreementTerms.map((term)=>Padding(
          padding:const EdgeInsets.only(bottom:10),child:Text(term))).toList()),
      CheckboxListTile(
        contentPadding:EdgeInsets.zero,value:accepted,
        onChanged:(value)=>setState(()=>accepted=value??false),
        title:const Text('The customer has read and accepted all terms and conditions.')),
      const Text('Customer signature',style:TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      Container(
        decoration:BoxDecoration(border:Border.all(color:Colors.grey),borderRadius:BorderRadius.circular(8)),
        child:Signature(controller:signature,height:180,backgroundColor:Colors.white)),
      Align(alignment:Alignment.centerRight,child:TextButton.icon(
        onPressed:(){signature.clear();setState(()=>agreement=null);},
        icon:const Icon(Icons.clear),label:const Text('Clear signature'))),
      FilledButton.icon(
        onPressed:busy?null:generate,
        icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.picture_as_pdf),
        label:Text(agreement==null?'Create Signed Agreement':'Recreate Signed Agreement')),
      const SizedBox(height:10),
      Row(children:[
        Expanded(child:OutlinedButton.icon(onPressed:busy?null:download,
          icon:const Icon(Icons.download),label:const Text('Download Agreement'))),
        const SizedBox(width:8),
        Expanded(child:FilledButton.icon(onPressed:busy?null:shareWhatsApp,
          icon:const Icon(Icons.share),label:const Text('Share via WhatsApp'))),
      ]),
      const SizedBox(height:8),
      const Text('The WhatsApp button opens Android sharing with the signed PDF attached; choose WhatsApp from the list.',
        style:TextStyle(fontSize:12,color:Colors.grey)),
    ]));
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});
  @override State<PaymentsPage> createState()=>_PaymentsPageState();
}
class _PaymentsPageState extends State<PaymentsPage>{
  List<List<String>> data=[],bookings=[],customers=[];
  final amount=TextEditingController();
  String method='UPI';
  String? selectedBookingId;
  @override void initState(){super.initState();load();}
  double totalFor(String id){for(final r in bookings){if(r.isNotEmpty&&r[0]==id)return r.length>5?double.tryParse(r[5])??0:0;}return 0;}
  double paidFor(String id)=>data.where((r)=>r.length>2&&r[1]==id)
    .fold<double>(0.0,(sum,r)=>sum+(double.tryParse(r[2])??0));
  double dueFor(String id){final due=totalFor(id)-paidFor(id);return due<0?0:due;}
  void updateDue(){if(selectedBookingId!=null)amount.text=dueFor(selectedBookingId!).toStringAsFixed(2);}
  Future<void> load()async{
    data=await db.rows('Payments');bookings=await db.rows('Bookings');customers=await db.rows('Customers');
    if(selectedBookingId!=null&&!bookings.any((r)=>r.isNotEmpty&&r[0]==selectedBookingId))selectedBookingId=null;
    updateDue();if(mounted)setState((){});
  }
  List<String>? selectedBooking(){
    for(final r in bookings){if(r.isNotEmpty&&r[0]==selectedBookingId)return r;}return null;
  }
  String customerName(String id){for(final r in customers){if(r.isNotEmpty&&r[0]==id)return r.length>1?r[1]:id;}return id;}
  Future<File> paymentQrFile()async{
    final data=await rootBundle.load('assets/payment_qr.png');final dir=await getApplicationDocumentsDirectory();
    final file=File('${dir.path}/DriveRent_Payment_QR.png');
    await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes,data.lengthInBytes),flush:true);return file;
  }
  Future<void> requestPayment(bool token)async{
    final booking=selectedBooking();if(booking==null)return;
    final balance=dueFor(booking[0]);
    if(!token&&balance<=0){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('This booking has no remaining balance.')));return;
    }
    final customer=customerName(booking.length>1?booking[1]:'');
    final amountToRequest=token?500.0:balance;
    final requestText=token
      ?'Please send INR 500 as the token amount using the attached QR code to confirm your booking.'
      :'Please send the remaining booking amount of INR ${amountToRequest.toStringAsFixed(2)} using the attached QR code.';
    final message='Hello $customer,\n\n$requestText\n\nBooking ID: ${booking[0]}\nTotal Booking Amount: INR ${totalFor(booking[0]).toStringAsFixed(2)}\nAmount Received: INR ${paidFor(booking[0]).toStringAsFixed(2)}\nRemaining Balance: INR ${balance.toStringAsFixed(2)}\nUPI ID: dineshjaware212@okhdfcbank\n\nThank you,\nGoCar Rental Services';
    final qr=await paymentQrFile();
    await Share.shareXFiles([XFile(qr.path)],subject:token?'Token payment request':'Remaining payment request',
      text:'$message\n\nSelect WhatsApp and choose the customer to send this payment request.');
  }
  Future<void> add()async{
    if(selectedBookingId==null)return;
    final value=double.tryParse(amount.text)??0;
    if(value<=0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Enter a valid payment amount.')));return;}
    await db.add('Payments',[newId(),selectedBookingId,value,method,DateTime.now().toIso8601String(),'']);
    final newPaid=paidFor(selectedBookingId!)+value;
    final status=newPaid>=totalFor(selectedBookingId!)-0.01?'Paid':'Partially Paid';
    await db.setValueById('Bookings',selectedBookingId!,11,status,header:'payment_status');
    await load();
  }
  Future<void> remove(String x)async{
    String? bookingId;
    for(final r in data){if(r.isNotEmpty&&r[0]==x){bookingId=r.length>1?r[1]:null;break;}}
    await db.deleteById('Payments',x);
    if(bookingId!=null){
      data=await db.rows('Payments');
      final paid=paidFor(bookingId),total=totalFor(bookingId);
      final status=paid<=0?'Booked':paid>=total-0.01?'Paid':'Partially Paid';
      await db.setValueById('Bookings',bookingId,11,status,header:'payment_status');
    }
    await load();
  }
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    const Text('Payments',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
    DropdownButtonFormField<String>(value:selectedBookingId,isExpanded:true,
      decoration:const InputDecoration(labelText:'Select booking',border:OutlineInputBorder()),
      items:bookings.map((r)=>DropdownMenuItem(value:r[0],child:Text('Booking ${shortBookingId(r[0])} • Due INR ${dueFor(r[0]).toStringAsFixed(2)}'))).toList(),
      onChanged:(v)=>setState((){selectedBookingId=v;updateDue();})),
    const SizedBox(height:8),
    if(selectedBookingId!=null)Card(color:Theme.of(context).colorScheme.primaryContainer,
      child:Padding(padding:const EdgeInsets.all(12),child:Text(
        'Total: INR ${totalFor(selectedBookingId!).toStringAsFixed(2)}   •   Paid: INR ${paidFor(selectedBookingId!).toStringAsFixed(2)}   •   Due: INR ${dueFor(selectedBookingId!).toStringAsFixed(2)}',
        style:const TextStyle(fontWeight:FontWeight.bold)))),
    if(selectedBookingId!=null)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
      Image.asset('assets/payment_qr.png',height:180,fit:BoxFit.contain),
      const Text('UPI: dineshjaware212@okhdfcbank',style:TextStyle(fontWeight:FontWeight.bold)),
      const SizedBox(height:8),
      SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()=>requestPayment(true),
        icon:const Icon(Icons.currency_rupee),label:const Text('Request INR 500 Token on WhatsApp'))),
      const SizedBox(height:8),
      SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>requestPayment(false),
        icon:const Icon(Icons.account_balance_wallet),label:const Text('Request Remaining Amount on WhatsApp'))),
    ]))),
    field(amount,'Payment amount (auto-filled balance)',number:true),
    DropdownButtonFormField<String>(value:method,
      decoration:const InputDecoration(labelText:'Payment method',border:OutlineInputBorder()),
      items:const ['UPI','Cash','Card','Bank Transfer'].map((m)=>DropdownMenuItem(value:m,child:Text(m))).toList(),
      onChanged:(v)=>setState(()=>method=v??'UPI')),
    const SizedBox(height:8),
    FilledButton.icon(onPressed:add,icon:const Icon(Icons.payments),label:const Text('Record Payment')),
    ...data.map((r)=>Card(child:ListTile(
      title:Text('₹${r.length>2?r[2]:''}'),
      subtitle:Text('Booking ${r.length>1?shortBookingId(r[1]):''} • ${r.length>3?r[3]:''}'),
      trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>remove(r[0])))))
  ]);
}

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});
  @override State<MaintenancePage> createState()=>_MaintenancePageState();
}
class _MaintenancePageState extends State<MaintenancePage>{
  List<List<String>> data=[]; final car=TextEditingController(),desc=TextEditingController(),cost=TextEditingController();
  @override void initState(){super.initState();load();}
  Future<void> load()async{data=await db.rows('Maintenance');if(mounted)setState((){});}
  Future<void> add()async{
    await db.add('Maintenance',[newId(),car.text,desc.text,'Scheduled',DateTime.now().toIso8601String(),double.tryParse(cost.text)??0,'']);
    car.clear();desc.clear();cost.clear();load();
  }
  Future<void> remove(String x)async{await db.deleteById('Maintenance',x);load();}
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    const Text('Maintenance',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
    field(car,'Vehicle ID / registration'),field(desc,'Service description'),field(cost,'Estimated cost (INR)',number:true),
    FilledButton.icon(onPressed:add,icon:const Icon(Icons.build),label:const Text('Add Service')),
    ...data.map((r)=>Card(child:ListTile(
      title:Text(r.length>2?r[2]:''),subtitle:Text('Car: ${r.length>1?r[1]:''} • ₹${r.length>5?r[5]:''} • ${r.length>3?r[3]:''}'),
      trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>remove(r[0])))))
  ]);
}

Widget field(TextEditingController c,String label,{bool number=false})=>Padding(
  padding:const EdgeInsets.only(bottom:8),
  child:TextField(controller:c,keyboardType:number?TextInputType.number:null,
    decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()))
);
