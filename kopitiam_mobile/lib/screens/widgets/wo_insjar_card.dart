import 'package:flutter/material.dart';
import '../../models/wo_insjar.dart';
import '../../widgets/branded_inspection_work_order_card.dart';

class WoInsjarCard extends StatelessWidget {
  final WoInsjar wo; final VoidCallback onStart,onOpen;
  const WoInsjarCard({super.key,required this.wo,required this.onStart,required this.onOpen});
  String get section => wo.section.trim().isNotEmpty?wo.section.trim():[wo.sectionAwal.trim(),wo.sectionAkhir.trim()].where((v)=>v.isNotEmpty).join(' → ');
  @override Widget build(BuildContext context){final status=WoInsjar.normalisasiStatus(wo.statusWo);return BrandedInspectionWorkOrderCard(code:wo.kodeWo,typeLabel:'INSPEKSI JARINGAN',status:status,title:wo.penyulang.trim().isEmpty?'Penyulang belum tersedia':wo.penyulang,subtitle:wo.tier.trim(),section:section,date:wo.tanggal,mapUrl:'',locationLabel:'',waiting:status==WoInsjar.statusMulai,finished:status==WoInsjar.statusSelesai,onStart:onStart,onOpen:onOpen);}
}
