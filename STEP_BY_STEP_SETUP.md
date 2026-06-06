# Supabase SQL Scripts - Step by Step Setup Guide

## 📋 Complete Setup Process

Yeh guide batayega ki kaise aap teeno SQL scripts ko Supabase Dashboard mein run kar sakte hain.

---

## Step 1: supabase_setup.sql Run Karein

### File Location:
`d:\main\supabase_setup.sql`

### Kaise Run Karein:

1. **Supabase Dashboard** open karein: https://supabase.com/dashboard
2. Apna project select karein (yuyitzuvsvxqsgnnubkt)
3. Left sidebar mein **SQL Editor** par click karein
4. **New Query** button click karein
5. `d:\main\supabase_setup.sql` file ko open karein
6. File ka **poora content** copy karein (Ctrl+A, Ctrl+C)
7. SQL Editor mein paste karein (Ctrl+V)
8. **Run** button click karein (bottom-right corner, green button)

### Kya Hoga:
- 19 tables create honge
- Indexes create honge
- Initial data insert hoga (vendor categories, default company)
- Triggers create honge

### Success Sign:
- Green checkmark ✅ dikhega
- "Success" message aayega
- Koi error nahi aayega

---

## Step 2: supabase_rls_policies.sql Run Karein

### File Location:
`d:\main\supabase_rls_policies.sql`

### Kaise Run Karein:

1. SQL Editor mein **New Query** button click karein
2. `d:\main\supabase_rls_policies.sql` file ko open karein
3. File ka **poora content** copy karein (Ctrl+A, Ctrl+C)
4. Naye query tab mein paste karein (Ctrl+V)
5. **Run** button click karein

### Kya Hoga:
- Row Level Security enable hoga sab tables par
- Security policies create honge
- Role-based access control setup hoga

### Success Sign:
- Green checkmark ✅ dikhega
- "Success" message aayega

---

## Step 3: supabase_functions_triggers.sql Run Karein

### File Location:
`d:\main\supabase_functions_triggers.sql`

### Kaise Run Karein:

1. SQL Editor mein **New Query** button click karein
2. `d:\main\supabase_functions_triggers.sql` file ko open karein
3. File ka **poora content** copy karein (Ctrl+A, Ctrl+C)
4. Naye query tab mein paste karein (Ctrl+V)
5. **Run** button click karein

### Kya Hoga:
- Auto-number generation functions create honge
- Business logic triggers create honge
- Helper functions create honge

### Success Sign:
- Green checkmark ✅ dikhega
- "Success" message aayega

---

## 🔍 Verification Steps

Sab scripts run hone ke baad verify karein:

### 1. Tables Check Karein:
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY table_name;
```

Expected output: 19 tables (companies, profiles, vendors, rfqs, quotations, approvals, etc.)

### 2. Functions Check Karein:
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public'
ORDER BY routine_name;
```

Expected output: Multiple functions (generate_rfq_number, get_dashboard_stats, etc.)

### 3. Triggers Check Karein:
```sql
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_schema = 'public'
ORDER BY event_object_table;
```

Expected output: Multiple triggers on various tables

---

## ⚠️ Common Errors aur Solutions

### Error: "relation already exists"
**Solution:** Maine already `IF NOT EXISTS` add kar diya hai. Phir se run karein.

### Error: "function already exists"
**Solution:** Functions mein `CREATE OR REPLACE` use kiya hai, error nahi aayega.

### Error: "permission denied"
**Solution:** Ensure karein ki aap correct project mein hain aur admin access hai.

### Error: "syntax error"
**Solution:** Poora file copy kiya hai ya sirf hissa? Poora content copy karein.

---

## ✅ Complete Checklist

- [ ] Step 1: supabase_setup.sql run kiya
- [ ] Step 2: supabase_rls_policies.sql run kiya
- [ ] Step 3: supabase_functions_triggers.sql run kiya
- [ ] Tables verify kiye (19 tables)
- [ ] Functions verify kiye
- [ ] Triggers verify kiye
- [ ] Koi error nahi aaya

---

## 🚀 Next Steps

Sab scripts successfully run hone ke baad:

1. **Test User Create Karein:**
   - Frontend mein jayein (index.html)
   - Register form se account create karein
   - Login try karein

2. **Dashboard Test Karein:**
   - Login ke baad dashboard open hoga
   - Data load hoga (agar initial data hai)

3. **RFQ Create Karein:**
   - RFQ form se test RFQ create karein
   - Database mein check karein

---

## 📞 Agar Help Chahiye

Agar koi error aaye:
1. Error message copy karein
2. Screenshot lein
3. Mujhe batayein

Main help kar dunga! 🎯
