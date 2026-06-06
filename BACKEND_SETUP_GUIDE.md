# VendorBridge - Complete Supabase Backend Setup Guide

## 📋 Overview

Yeh guide aapko step-by-step batayega ki kaise aap VendorBridge ka complete Supabase backend setup kar sakte hain. Isme database schema, RLS policies, functions, triggers, aur frontend integration sab kuch included hai.

---

## 🚀 Setup Steps

### Step 1: Supabase Project Create Karein

1. [Supabase Dashboard](https://supabase.com/dashboard) par jayein
2. "New Project" click karein
3. Project details fill karein:
   - **Name**: vendorbridge
   - **Database Password**: Strong password set karein
   - **Region**: Apne region select karein (e.g., Mumbai)
4. "Create new project" click karein
5. Project create hone ka wait karein (2-3 minutes lag sakte hain)

---

### Step 2: Database Setup SQL Run Karein

1. Supabase Dashboard mein apne project par click karein
2. Left sidebar se **SQL Editor** select karein
3. **New Query** button click karein
4. `supabase_setup.sql` file ka content copy karein
5. SQL Editor mein paste karein
6. **Run** button click karein (bottom-right corner)
7. Sab tables create ho jayenge

**Files to run in order:**
1. ✅ `supabase_setup.sql` - Tables creation
2. ✅ `supabase_rls_policies.sql` - Security policies
3. ✅ `supabase_functions_triggers.sql` - Business logic

---

### Step 3: Environment Variables Configure Karein

Apne frontend mein Supabase credentials update karein:

```javascript
// index.html mein (line 301-302)
const _SUPABASE_URL = 'https://your-project-id.supabase.co'; 
const _SUPABASE_ANON_KEY = 'your-anon-key-here';
```

**Credentials kaise milein:**
1. Supabase Dashboard → **Settings** → **API**
2. **Project URL** copy karein
3. **anon public** key copy karein
4. Index.html mein replace karein

---

### Step 4: Authentication Setup

Supabase Auth already configured hai, bas settings check karein:

1. **Settings** → **Authentication** → **Providers**
2. **Email** provider enable hai ensure karein
3. **Confirm email** option disable karein (testing ke liye)
4. **Email templates** customize kar sakte hain agar chahiye

---

### Step 5: Storage Setup (Optional)

Agar file upload feature use karna hai:

1. **Storage** tab par jayein
2. **New bucket** create karein:
   - **Name**: documents
   - **Public bucket**: No
3. Bucket policies setup karein:
   - Authenticated users can upload
   - Public can read (agar required)

---

### Step 6: Test Data Insert Karein

SQL Editor mein ye query run karein test data ke liye:

```sql
-- Test user create karein
INSERT INTO profiles (id, email, full_name, role) VALUES
('test-user-id', 'test@vendorbridge.com', 'Test Officer', 'officer');

-- Test vendor create karein
INSERT INTO vendors (business_name, contact_email, contact_phone, category_id, is_verified) VALUES
('Matrix Tech Solved Ltd.', 'sales@matrixtech.com', '+91-9876543210', 
 (SELECT id FROM vendor_categories WHERE name = 'Hardware IT'), true);

-- Test RFQ create karein
INSERT INTO rfqs (title, description, submission_deadline, created_by, status) VALUES
('High-Core Servers Procurement', 'Need 2 high-core servers for data center', 
 NOW() + INTERVAL '7 days', 'test-user-id', 'published');
```

---

## 📊 Database Schema Summary

### Main Tables

| Table | Purpose |
|-------|---------|
| `profiles` | User profiles with roles |
| `companies` | Company/organization details |
| `vendors` | Vendor registration |
| `vendor_categories` | Vendor categorization |
| `rfqs` | Request for Quotations |
| `quotations` | Vendor quotations |
| `approvals` | Approval workflow |
| `purchase_orders` | Purchase orders |
| `invoices` | Invoices |
| `audit_logs` | System audit trail |

### User Roles

- **officer**: Procurement Officer - RFQs create kar sakte hain
- **vendor**: Vendor Partner - Quotations submit kar sakte hain
- **manager**: Department Manager - Approvals kar sakte hain
- **admin**: System Admin - Full access

---

## 🔒 Security Features

### Row Level Security (RLS)

Sab tables par RLS enabled hai jo ensure karta hai:
- Users sirf apni data access kar sakte hain
- Role-based access control
- Vendors sirf assigned RFQs dekh sakte hain
- Officers sab RFQs manage kar sakte hain

### Key Security Policies

1. **Profiles**: Users sirf apna profile dekh/update kar sakte hain
2. **Vendors**: Public verified vendors dekh sakte hain
3. **RFQs**: Officers sab RFQs dekh sakte hain, vendors sirf invited RFQs
4. **Quotations**: Vendors sirf apni quotations dekh sakte hain
5. **Approvals**: Managers pending approvals dekh sakte hain

---

## ⚡ Database Functions & Triggers

### Auto-Generated Numbers

- **RFQ Numbers**: RFQ-2026-0001, RFQ-2026-0002...
- **Quotation Numbers**: QTN-2026-0001...
- **Approval Numbers**: APR-2026-0001...
- **PO Numbers**: PO-2026-0001...
- **Invoice Numbers**: INV-2026-0001...

### Automatic Calculations

- **Quotation totals**: Items se automatically calculate
- **PO totals**: Subtotal + IGST automatically calculate
- **Invoice totals**: Subtotal + IGST automatically calculate
- **Vendor ratings**: Average automatically update
- **Lowest quotation**: Automatically mark

### Useful Functions

```sql
-- Dashboard stats get karne ke liye
SELECT get_dashboard_stats('user-id');

-- RFQ with quotations get karne ke liye
SELECT get_rfq_with_quotations('rfq-id');

-- Vendor performance check karne ke liye
SELECT get_vendor_performance('vendor-id');

-- Invoice create karne ke liye
SELECT create_invoice_from_po('po-id');

-- Audit log entry karne ke liye
SELECT log_audit('user-id', 'action', 'entity_type', 'entity_id', '{"key": "value"}');
```

---

## 🔧 Frontend Integration

### Login Flow

Frontend already Supabase integrated hai. Login flow:

1. User email/password enter karta hai
2. `supabaseClient.auth.signInWithPassword()` call hota hai
3. Supabase auth verify karta hai
4. Success par dashboard redirect hota hai

### Register Flow

1. User company name, email, password enter karta hai
2. `supabaseClient.auth.signUp()` call hota hai
3. Profile automatically create hota hai (trigger se)
4. User login page par redirect hota hai

### Session Management

```javascript
// Check if user is logged in
const { data: { session } } = await supabaseClient.auth.getSession();

// Get current user
const { data: { user } } = await supabaseClient.auth.getUser();

// Logout
await supabaseClient.auth.signOut();
```

---

## 📝 Common Queries

### RFQs List Get Karne ke liye

```javascript
const { data, error } = await supabaseClient
  .from('rfqs')
  .select(`
    *,
    profiles:created_by (full_name),
    rfq_items (*)
  `)
  .eq('status', 'published')
  .order('created_at', { ascending: false });
```

### Quotations Submit Karne ke liye

```javascript
const { data, error } = await supabaseClient
  .from('quotations')
  .insert({
    rfq_id: 'rfq-id',
    vendor_id: 'vendor-id',
    total_amount: 340000,
    delivery_timeline: '7 days',
    remarks: 'Best price offered'
  });
```

### Approval Request Karne ke liye

```javascript
const { data, error } = await supabaseClient
  .from('approvals')
  .insert({
    rfq_id: 'rfq-id',
    quotation_id: 'quotation-id',
    requested_by: 'user-id',
    title: 'Approval for RFQ-2026-001',
    amount: 340000,
    status: 'pending'
  });
```

---

## 🐛 Troubleshooting

### Issue: Login not working

**Solution:**
1. Check karein ki Supabase URL aur Anon key correct hain
2. Browser console mein error check karein
3. Supabase Dashboard mein Auth settings verify karein

### Issue: RLS policy error

**Solution:**
1. SQL Editor mein `supabase_rls_policies.sql` run karein
2. Check karein ki user role correct hai
3. `SELECT * FROM profiles WHERE id = auth.uid();` run karke check karein

### Issue: Trigger not firing

**Solution:**
1. `supabase_functions_triggers.sql` dubara run karein
2. Check karein ki function exist karti hai: `\df function_name`
3. Error logs check karein Supabase Dashboard mein

---

## 📚 Additional Resources

### Supabase Documentation
- [Auth](https://supabase.com/docs/guides/auth)
- [Database](https://supabase.com/docs/guides/database)
- [RLS](https://supabase.com/docs/guides/auth/row-level-security)
- [Functions](https://supabase.com/docs/guides/database/functions)

### Project Files

1. **supabase_backend_design.md** - Complete schema design
2. **supabase_setup.sql** - Tables creation script
3. **supabase_rls_policies.sql** - Security policies
4. **supabase_functions_triggers.sql** - Business logic

---

## ✅ Setup Checklist

- [ ] Supabase project created
- [ ] `supabase_setup.sql` executed
- [ ] `supabase_rls_policies.sql` executed
- [ ] `supabase_functions_triggers.sql` executed
- [ ] Environment variables updated in frontend
- [ ] Test user created
- [ ] Test vendor created
- [ ] Login flow tested
- [ ] Register flow tested
- [ ] RFQ creation tested
- [ ] Quotation submission tested

---

## 🎯 Next Steps

Setup complete hone ke baad:

1. **Dashboard Integration**: Dashboard.html mein real data load karein
2. **Vendor Management**: Vendors page ko Supabase connect karein
3. **RFQ Workflow**: RFQ creation flow complete karein
4. **Quotation System**: Vendor quotation submission implement karein
5. **Approval Workflow**: Manager approval system build karein
6. **Invoice Generation**: PO se invoice auto-generation implement karein

---

## 🆘 Support

Agar koi issue aata hai:
1. Supabase Dashboard logs check karein
2. Browser console errors dekhein
3. SQL queries test karein SQL Editor mein
4. Documentation refer karein

---

**Happy Coding! 🚀**
