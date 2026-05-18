import React from 'react';
import { Page, Text, View, Document, StyleSheet, Font, renderToBuffer } from '@react-pdf/renderer';
import path from 'path';
import { ArabicShaper } from 'arabic-persian-reshaper';

// On Vercel, public files are in process.cwd()/public
const fontDir = path.join(process.cwd(), 'public', 'fonts');

try {
  Font.register({
    family: 'Amiri',
    fonts: [
      { src: path.join(fontDir, 'Amiri-Regular.ttf') },
      { src: path.join(fontDir, 'Amiri-Bold.ttf'), fontWeight: 'bold' },
    ]
  });
} catch (e) {
  console.warn("Could not register fonts. Ensure public/fonts/Amiri-Regular.ttf exists.", e);
}

const styles = StyleSheet.create({
  page: {
    flexDirection: 'column',
    backgroundColor: '#FFFFFF',
    padding: 30,
    fontFamily: 'Amiri',
  },
  header: {
    textAlign: 'center',
    marginBottom: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#d2b48c',
    paddingBottom: 10,
  },
  headerTextAr: { fontSize: 16, fontWeight: 'bold', marginBottom: 2 },
  headerTextFr: { fontSize: 11, marginBottom: 2 },
  headerSub: { fontSize: 10, marginBottom: 2 },
  titleAr: { fontSize: 18, fontWeight: 'bold', marginBottom: 5, marginTop: 10 },
  titleFr: { fontSize: 12, marginBottom: 10 },
  sectionTitle: {
    fontSize: 14,
    fontWeight: 'bold',
    backgroundColor: '#f5f0e6',
    padding: 5,
    marginBottom: 10,
    textAlign: 'right',
  },
  row: {
    flexDirection: 'row-reverse',
    marginBottom: 8,
  },
  labelContainer: {
    width: 200,
  },
  labelAr: { fontSize: 12, fontWeight: 'bold', textAlign: 'right' },
  labelFr: { fontSize: 9, color: '#666666', textAlign: 'right', marginTop: 1 },
  value: { fontSize: 12, textAlign: 'right', flex: 1, marginRight: 10 },
  stamp: {
    marginTop: 40,
    borderTopWidth: 1,
    borderTopColor: '#d2b48c',
    paddingTop: 10,
    flexDirection: 'row-reverse',
    justifyContent: 'space-between',
  },
  stampText: { fontSize: 10, textAlign: 'center' },
  stampFr: { fontSize: 9, color: '#666666', textAlign: 'center', marginTop: 2 }
});

// Helper for Arabic text
const ar = (text: string | null | undefined) => {
  if (!text) return "---";
  return text;
};

const Header = ({ titleAr, titleFr }: { titleAr: string, titleFr: string }) => (
  <View style={styles.header}>
    <Text style={styles.headerTextAr}>{ar('المملكة المغربية')}</Text>
    <Text style={styles.headerTextFr}>Royaume du Maroc</Text>
    <Text style={styles.headerSub}>{ar('وزارة الداخلية')}</Text>
    <Text style={styles.headerSub}>{ar('مصلحة الحالة المدنية')}</Text>
    <Text style={styles.headerSub}>Service de l'Etat Civil</Text>
    
    <Text style={styles.titleAr}>{ar(titleAr)}</Text>
    <Text style={styles.titleFr}>{titleFr}</Text>
  </View>
);

const FieldRow = ({ labelAr, labelFr, value }: { labelAr: string, labelFr?: string, value: string }) => (
  <View style={styles.row}>
    <View style={styles.labelContainer}>
      <Text style={styles.labelAr}>{ar(labelAr)}</Text>
      {labelFr && <Text style={styles.labelFr}>{labelFr}</Text>}
    </View>
    <Text style={styles.value}>{ar(value)}</Text>
  </View>
);

export async function generateBirthPDFBuffer(data: any): Promise<Buffer> {
  const doc = (
    <Document>
      <Page size="A4" style={styles.page}>
        <Header titleAr="نسخة موجزة من رسم الولادة" titleFr="Extrait d'Acte de Naissance" />
        
        <Text style={styles.sectionTitle}>{ar('معلومات المولود')}</Text>
        <FieldRow labelAr="الاسم الشخصي" labelFr="Prénom" value={data.newborn_fname} />
        <FieldRow labelAr="تاريخ الازدياد" labelFr="Date de naissance" value={data.newborn_dob} />
        <FieldRow labelAr="مكان الازدياد" labelFr="Lieu de naissance" value={data.newborn_birthplace} />
        <FieldRow labelAr="الجنس" labelFr="Sexe" value={data.gender === 'M' ? 'ذكر' : 'أنثى'} />

        <Text style={styles.sectionTitle}>{ar('معلومات الأب')}</Text>
        <FieldRow labelAr="الاسم الشخصي" value={data.father_fname} />
        <FieldRow labelAr="الاسم العائلي" value={data.father_lname} />
        <FieldRow labelAr="تاريخ الازدياد" value={data.father_dob} />
        <FieldRow labelAr="رقم البطاقة الوطنية" value={data.father_cin} />

        <Text style={styles.sectionTitle}>{ar('معلومات الأم')}</Text>
        <FieldRow labelAr="الاسم الشخصي" value={data.mother_fname} />
        <FieldRow labelAr="الاسم العائلي" value={data.mother_lname} />
        <FieldRow labelAr="تاريخ الازدياد" value={data.mother_dob} />
        <FieldRow labelAr="رقم البطاقة الوطنية" value={data.mother_cin} />
        <FieldRow labelAr="العنوان" value={data.mother_address} />

        <View style={styles.stamp}>
          <View style={{ width: 150 }}>
            <Text style={styles.stampText}>{ar('خاتم وتوقيع ضابط الحالة المدنية')}</Text>
            <Text style={styles.stampFr}>Cachet et signature de l'OEC</Text>
          </View>
          <View style={{ width: 150 }}>
            <Text style={styles.stampText}>{ar(`حرر بتاريخ: ${new Date().toISOString().split('T')[0]}`)}</Text>
          </View>
        </View>
      </Page>
    </Document>
  );

  return renderToBuffer(doc);
}

export async function generateDeathPDFBuffer(data: any): Promise<Buffer> {
  const doc = (
    <Document>
      <Page size="A4" style={styles.page}>
        <Header titleAr="نسخة كاملة من رسم الوفاة" titleFr="Copie Intégrale d'Acte de Décès" />
        
        <Text style={styles.sectionTitle}>{ar('معلومات المتوفى')}</Text>
        <FieldRow labelAr="الاسم الشخصي" value={data.deceased_fname} />
        <FieldRow labelAr="الاسم العائلي" value={data.deceased_lname} />
        <FieldRow labelAr="الجنس" value={data.dgender === 'M' ? 'ذكر' : 'أنثى'} />
        <FieldRow labelAr="تاريخ الوفاة" value={data.death_date} />
        <FieldRow labelAr="مكان الوفاة" value={data.death_place} />
        <FieldRow labelAr="سبب الوفاة" value={data.cause_death} />

        <Text style={styles.sectionTitle}>{ar('معلومات الأب')}</Text>
        <FieldRow labelAr="الاسم الشخصي" value={data.father_fname} />
        <FieldRow labelAr="الاسم العائلي" value={data.father_lname} />

        <Text style={styles.sectionTitle}>{ar('معلومات الأم')}</Text>
        <FieldRow labelAr="الاسم الشخصي" value={data.mother_fname} />
        <FieldRow labelAr="الاسم العائلي" value={data.mother_lname} />

        <Text style={styles.sectionTitle}>{ar('معلومات المصرح')}</Text>
        <FieldRow labelAr="الاسم الكامل" value={data.declarant_name} />
        <FieldRow labelAr="رقم البطاقة الوطنية" value={data.declarant_cin} />
        <FieldRow labelAr="نوع التصريح" value={data.dtype === 'direct' ? 'مباشر' : 'بموجب حكم'} />
        <FieldRow labelAr="تاريخ التصريح" value={data.decl_date} />

        <View style={styles.stamp}>
          <View style={{ width: 150 }}>
            <Text style={styles.stampText}>{ar('خاتم وتوقيع ضابط الحالة المدنية')}</Text>
            <Text style={styles.stampFr}>Cachet et signature de l'OEC</Text>
          </View>
          <View style={{ width: 150 }}>
            <Text style={styles.stampText}>{ar(`حرر بتاريخ: ${new Date().toISOString().split('T')[0]}`)}</Text>
          </View>
        </View>
      </Page>
    </Document>
  );

  return renderToBuffer(doc);
}
