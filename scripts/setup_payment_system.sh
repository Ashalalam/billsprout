#!/bin/bash

# LifeSprout Payment System Setup Script
# This script helps set up the payment system infrastructure

set -e

echo "🚀 LifeSprout Payment System Setup"
echo "===================================="
echo ""

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Please install it first:"
    echo "   npm install -g supabase"
    exit 1
fi

echo "✅ Supabase CLI found"
echo ""

# Check if logged in to Supabase
if ! supabase projects list &> /dev/null; then
    echo "❌ Not logged in to Supabase. Please login:"
    echo "   supabase login"
    exit 1
fi

echo "✅ Logged in to Supabase"
echo ""

# Link to project
read -p "Enter your Supabase project ref (e.g., abcdefghijklmnop): " PROJECT_REF

if [ -z "$PROJECT_REF" ]; then
    echo "❌ Project ref is required"
    exit 1
fi

echo "🔗 Linking to project: $PROJECT_REF"
supabase link --project-ref $PROJECT_REF

echo ""
echo "📦 Step 1: Applying Database Migrations"
echo "========================================"

# Apply migrations
echo "Applying migration 012_subscription_plans_payments.sql..."
supabase db push

echo "✅ Migrations applied successfully"
echo ""

echo "🔧 Step 2: Setting Up Environment Variables"
echo "==========================================="

# Collect Razorpay credentials
echo ""
echo "Please enter your Razorpay credentials:"
echo "(Use test mode credentials for development)"
echo ""

read -p "Razorpay Key ID (rzp_test_XXXX): " RAZORPAY_KEY_ID
read -p "Razorpay Key Secret: " -s RAZORPAY_KEY_SECRET
echo ""
read -p "Razorpay Webhook Secret: " -s RAZORPAY_WEBHOOK_SECRET
echo ""

# Collect email service credentials
echo ""
echo "Please enter your Resend credentials:"
echo "(Sign up at https://resend.com if you don't have an account)"
echo ""

read -p "Resend API Key: " -s RESEND_API_KEY
echo ""
read -p "From Email Address: " FROM_EMAIL

echo ""
echo "Setting secrets..."

# Set secrets
supabase secrets set \
  RAZORPAY_KEY_ID="$RAZORPAY_KEY_ID" \
  RAZORPAY_KEY_SECRET="$RAZORPAY_KEY_SECRET" \
  RAZORPAY_WEBHOOK_SECRET="$RAZORPAY_WEBHOOK_SECRET" \
  RESEND_API_KEY="$RESEND_API_KEY" \
  FROM_EMAIL="$FROM_EMAIL"

echo "✅ Secrets configured"
echo ""

echo "☁️  Step 3: Deploying Edge Functions"
echo "====================================="

# Deploy edge functions
echo "Deploying create-razorpay-order..."
supabase functions deploy create-razorpay-order

echo "Deploying verify-razorpay-payment..."
supabase functions deploy verify-razorpay-payment

echo "Deploying razorpay-webhook..."
supabase functions deploy razorpay-webhook

echo "Deploying send-email..."
supabase functions deploy send-email

echo "✅ Edge functions deployed"
echo ""

echo "🔗 Step 4: Webhook Configuration"
echo "================================"

# Get project URL
PROJECT_URL=$(supabase status | grep "API URL" | awk '{print $3}')
WEBHOOK_URL="${PROJECT_URL}/functions/v1/razorpay-webhook"

echo ""
echo "📋 Configure your Razorpay webhook:"
echo "1. Go to https://dashboard.razorpay.com/app/webhooks"
echo "2. Click 'Add New Webhook'"
echo "3. Enter webhook URL: $WEBHOOK_URL"
echo "4. Select events:"
echo "   - payment.captured"
echo "   - payment.failed"
echo "   - order.paid"
echo "5. Enter webhook secret (you provided earlier)"
echo "6. Click 'Create Webhook'"
echo ""

read -p "Press Enter after configuring the webhook..."

echo ""
echo "✅ Setup Complete!"
echo "=================="
echo ""
echo "📝 Next Steps:"
echo "1. Test the payment flow in your Flutter app"
echo "2. Use test card: 4111 1111 1111 1111 for successful payments"
echo "3. Use test card: 4000 0000 0000 0002 for failed payments"
echo "4. Check webhook logs in Razorpay dashboard"
echo "5. Verify subscription activation in Supabase database"
echo ""
echo "📚 Documentation:"
echo "   See PAYMENT_SYSTEM_DEPLOYMENT_GUIDE.md for detailed testing instructions"
echo ""
echo "🐛 Troubleshooting:"
echo "   - View function logs: supabase functions logs <function-name>"
echo "   - View database: supabase db remote"
echo "   - Test webhook: Check webhook_logs table"
echo ""
echo "🎉 Happy coding!"
