import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
    title: 'DriveRent Manager',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
    home: const DashboardPage(),
  );
}

class LocalExcelDb {
  static const sheets = ['Cars','Customers','Bookings','Payments','Maintenance','Settings'];

  Future<File> file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/DriveRent_Database.xlsx');
  }

  Future<void> ensure() async {
    final f = await file();
    if (await f.exists()) return;
    final e = Excel.createExcel();
    e.delete('Sheet1');
    e['Cars'].appendRow(toCellValues(['id','name','registration','daily_rate','status','odometer']));
    e['Customers'].appendRow(toCellValues(['id','name','phone','license_number','address','notes']));
    e['Bookings'].appendRow(toCellValues(['id','customer_id','car_id','pickup_at','return_at','amount','deposit','status']));
    e['Payments'].appendRow(toCellValues(['id','booking_id','amount','method','paid_at','notes']));
    e['Maintenance'].appendRow(toCellValues(['id','car_id','description','status','scheduled_at','cost','notes']));
    e['Settings'].appendRow(toCellValues(['business_name','currency']));
    e['Settings'].appendRow(toCellValues(['DriveRent','INR']));
    await f.writeAsBytes(e.encode()!);
  }

  Future<Excel> open() async {
    await ensure();
    return Excel.decodeBytes(await (await file()).readAsBytes());
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
      text: 'DriveRent Manager Excel backup');
}

final db = LocalExcelDb();
String newId() => DateTime.now().microsecondsSinceEpoch.toString();

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  int tab = 0;
  final pages = const [
    HomePage(), CarsPage(), CustomersPage(), BookingsPage(), PaymentsPage(), MaintenancePage()
  ];
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('DriveRent Manager')),
    body: pages[tab],
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.directions_car), label: 'Cars'),
        NavigationDestination(icon: Icon(Icons.people), label: 'Customers'),
        NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Bookings'),
        NavigationDestination(icon: Icon(Icons.payments), label: 'Payments'),
        NavigationDestination(icon: Icon(Icons.build), label: 'Service'),
      ],
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  Map<String,int> n = {};
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final m = <String,int>{};
    for (final s in LocalExcelDb.sheets.take(5)) m[s] = (await db.rows(s)).length;
    if (mounted) setState(() => n = m);
  }
  @override
  Widget build(BuildContext c) => RefreshIndicator(
    onRefresh: load,
    child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Rental Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        metric('Cars', n['Cars'] ?? 0, Icons.directions_car),
        metric('Customers', n['Customers'] ?? 0, Icons.people),
        metric('Bookings', n['Bookings'] ?? 0, Icons.calendar_month),
        metric('Payments', n['Payments'] ?? 0, Icons.payments),
        metric('Service', n['Maintenance'] ?? 0, Icons.build),
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
  Widget metric(String t, int v, IconData i) => SizedBox(
    width: 155, child: Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [Icon(i,size:30), Text('$v',style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold)), Text(t)]))));
}

class CarsPage extends StatefulWidget {
  const CarsPage({super.key});
  @override State<CarsPage> createState() => _CarsPageState();
}
class _CarsPageState extends State<CarsPage> {
  List<List<String>> data=[]; final name=TextEditingController(), reg=TextEditingController(), rate=TextEditingController();
  @override void initState(){super.initState();load();}
  Future<void> load()async{data=await db.rows('Cars');if(mounted)setState((){});}
  Future<void> add()async{
    if(name.text.trim().isEmpty||reg.text.trim().isEmpty)return;
    await db.add('Cars',[newId(),name.text.trim(),reg.text.trim(),double.tryParse(rate.text)??0,'Available',0]);
    name.clear();reg.clear();rate.clear();load();
  }
  Future<void> remove(String x)async{await db.deleteById('Cars',x);load();}
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    const Text('Cars',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
    field(name,'Car name'),field(reg,'Registration'),field(rate,'Daily rate (INR)',number:true),
    FilledButton.icon(onPressed:add,icon:const Icon(Icons.add),label:const Text('Add Car')),
    ...data.map((r)=>Card(child:ListTile(
      leading:const Icon(Icons.directions_car),
      title:Text(r.length>1?r[1]:''),
      subtitle:Text('${r.length>2?r[2]:''} • ₹${r.length>3?r[3]:''} • ${r.length>4?r[4]:''}'),
      trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>remove(r[0])))))
  ]);
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
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    const Text('Customers',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
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
  List<List<String>> data=[]; final customer=TextEditingController(),car=TextEditingController(),amount=TextEditingController(),deposit=TextEditingController();
  DateTime pickup=DateTime.now(), ret=DateTime.now().add(const Duration(days:1));
  @override void initState(){super.initState();load();}
  Future<void> load()async{data=await db.rows('Bookings');if(mounted)setState((){});}
  Future<void> pick(bool isPickup)async{
    final d=await showDatePicker(context:context,initialDate:isPickup?pickup:ret,firstDate:DateTime(2020),lastDate:DateTime(2100));
    if(d!=null)setState(()=>isPickup?pickup=d:ret=d);
  }
  Future<void> add()async{
    await db.add('Bookings',[newId(),customer.text,car.text,pickup.toIso8601String(),ret.toIso8601String(),
      double.tryParse(amount.text)??0,double.tryParse(deposit.text)??0,'Booked']);
    customer.clear();car.clear();amount.clear();deposit.clear();load();
  }
  Future<void> remove(String x)async{await db.deleteById('Bookings',x);load();}
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    const Text('Bookings',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
    field(customer,'Customer ID / name'),field(car,'Car ID / registration'),
    field(amount,'Rental amount (INR)',number:true),field(deposit,'Deposit (INR)',number:true),
    Row(children:[Expanded(child:Text('Pickup: ${DateFormat('dd MMM yyyy').format(pickup)}')),TextButton(onPressed:()=>pick(true),child:const Text('Change'))]),
    Row(children:[Expanded(child:Text('Return: ${DateFormat('dd MMM yyyy').format(ret)}')),TextButton(onPressed:()=>pick(false),child:const Text('Change'))]),
    FilledButton.icon(onPressed:add,icon:const Icon(Icons.event_available),label:const Text('Create Booking')),
    ...data.map((r)=>Card(child:ListTile(
      title:Text('Booking ${r[0].substring(r[0].length-6)}'),
      subtitle:Text('Customer: ${r.length>1?r[1]:''} • Car: ${r.length>2?r[2]:''}\nAmount: ₹${r.length>5?r[5]:''} • Deposit: ₹${r.length>6?r[6]:''} • ${r.length>7?r[7]:''}'),
      isThreeLine:true,trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>remove(r[0])))))
  ]);
}

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});
  @override State<PaymentsPage> createState()=>_PaymentsPageState();
}
class _PaymentsPageState extends State<PaymentsPage>{
  List<List<String>> data=[]; final booking=TextEditingController(),amount=TextEditingController(),method=TextEditingController();
  @override void initState(){super.initState();load();}
  Future<void> load()async{data=await db.rows('Payments');if(mounted)setState((){});}
  Future<void> add()async{
    await db.add('Payments',[newId(),booking.text,double.tryParse(amount.text)??0,method.text,DateTime.now().toIso8601String(),'']);
    booking.clear();amount.clear();method.clear();load();
  }
  Future<void> remove(String x)async{await db.deleteById('Payments',x);load();}
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
    const Text('Payments',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),
    field(booking,'Booking ID'),field(amount,'Amount (INR)',number:true),field(method,'Method (Cash / UPI / Card)'),
    FilledButton.icon(onPressed:add,icon:const Icon(Icons.payments),label:const Text('Record Payment')),
    ...data.map((r)=>Card(child:ListTile(
      title:Text('₹${r.length>2?r[2]:''}'),
      subtitle:Text('Booking: ${r.length>1?r[1]:''} • ${r.length>3?r[3]:''}'),
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
    field(car,'Car ID / registration'),field(desc,'Service description'),field(cost,'Estimated cost (INR)',number:true),
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
