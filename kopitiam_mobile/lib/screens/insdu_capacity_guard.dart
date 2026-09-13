import 'package:flutter/material.dart';
import '../models/wo_insdu.dart';

class InsduCurrentWarning {
  final String period;
  final String phase;
  final double value;
  final double limit;
  const InsduCurrentWarning(this.period,this.phase,this.value,this.limit);
}

class InsduCapacityGuard {
  static List<InsduCurrentWarning> evaluate({required int capacity,required Map<String,double?> values}){
    final phaseLimit=WoInsdu.maximumPhaseCurrent(capacity),result=<InsduCurrentWarning>[];
    void phase(String key,String period,String label){final value=values[key];if(value!=null&&value>phaseLimit)result.add(InsduCurrentWarning(period,label,value,phaseLimit));}
    void neutral(String key,String period){final value=values[key];if(value!=null&&value>100)result.add(InsduCurrentWarning(period,'Netral N',value,100));}
    phase('bebanUtamaRWbp','WBP','Fasa R');phase('bebanUtamaSWbp','WBP','Fasa S');phase('bebanUtamaTWbp','WBP','Fasa T');neutral('bebanJurusanNWbp','WBP');
    phase('bebanUtamaRLwbp','LWBP','Fasa R');phase('bebanUtamaSLwbp','LWBP','Fasa S');phase('bebanUtamaTLwbp','LWBP','Fasa T');neutral('bebanJurusanNLwbp','LWBP');
    return result;
  }

  static Future<bool> confirm(BuildContext context,{required int capacity,required List<InsduCurrentWarning> warnings})async{
    if(warnings.isEmpty)return true;
    return await showDialog<bool>(context:context,builder:(dialogContext)=>AlertDialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
      icon:Icon(Icons.warning_amber_rounded,color:Colors.red.shade700,size:48),
      title:const Text('Arus melebihi batas'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Kapasitas $capacity kVA pada 400 V. Periksa kembali hasil ukur berikut:'),
        const SizedBox(height:14),
        ...warnings.map((warning)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[Expanded(child:Text('${warning.period} • ${warning.phase}',style:const TextStyle(fontWeight:FontWeight.w700))),Text('${warning.value.toStringAsFixed(1).replaceAll('.',',')} A  >  ${warning.limit.toStringAsFixed(1).replaceAll('.',',')} A',style:TextStyle(color:Colors.red.shade700,fontWeight:FontWeight.w800))]))),
        const SizedBox(height:4),const Text('Jika hasil ukur benar, lanjutkan ke konfirmasi akhir sebelum menyimpan.',style:TextStyle(color:Color(0xFF64748B))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Periksa kembali')),FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.red.shade700,foregroundColor:Colors.white),onPressed:()=>Navigator.pop(dialogContext,true),child:const Text('Data benar, lanjutkan'))],
    ))??false;
  }
}
