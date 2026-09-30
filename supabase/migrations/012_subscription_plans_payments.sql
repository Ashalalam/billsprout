-- =====================================================
-- BillSprout/LifeSprout - Subscription Plans & Payment Tables
-- =====================================================
-- This migration creates tables for subscription management and payment processing
-- Created: 2024
-- Description: Subscription plans, pricing tiers, payment transactions, and webhooks

-- =====================================================
-- 1. SUBSCRIPTION PLANS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS subscription_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_name VARCHAR(100) NOT NULL UNIQUE,
    plan_code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    price_monthly DECIMAL(10,2) NOT NULL,
    price_yearly DECIMAL(10,2) NOT NULL,
    price_currency VARCHAR(3) DEFAULT 'INR',
    max_branches INTEGER NOT NULL DEFAULT 1,
    max_users INTEGER NOT NULL DEFAULT 5,
    max_products INTEGER NOT NULL DEFAULT 1000,
    max_invoices_per_month INTEGER NOT NULL DEFAULT 500,
    features JSONB, -- JSON array of feature names
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 2. TENANT SUBSCRIPTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS tenant_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
    billing_cycle VARCHAR(20) NOT NULL CHECK (billing_cycle IN ('monthly', 'yearly', 'trial')),
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'expired', 'cancelled', 'suspended')),
    amount_paid DECIMAL(10,2),
    payment_method VARCHAR(50),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    auto_renew BOOLEAN DEFAULT true,
    razorpay_subscription_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for tenant subscription lookups
CREATE INDEX idx_tenant_subscriptions_tenant ON tenant_subscriptions(tenant_id);
CREATE INDEX idx_tenant_subscriptions_status ON tenant_subscriptions(status);

-- =====================================================
-- 3. PAYMENT TRANSACTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS payment_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES tenant_subscriptions(id) ON DELETE SET NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'processing', 'success', 'failed', 'refunded')),
    payment_method VARCHAR(50),
    payment_gateway VARCHAR(50) DEFAULT 'razorpay',
    
    -- Razorpay specific fields
    razorpay_order_id VARCHAR(255),
    razorpay_payment_id VARCHAR(255),
    razorpay_signature VARCHAR(500),
    
    -- Transaction metadata
    transaction_type VARCHAR(50) CHECK (transaction_type IN ('subscription', 'renewal', 'upgrade', 'refund')),
    description TEXT,
    metadata JSONB,
    
    -- Timestamps
    payment_initiated_at TIMESTAMP WITH TIME ZONE,
    payment_completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for payment lookups
CREATE INDEX idx_payment_transactions_tenant ON payment_transactions(tenant_id);
CREATE INDEX idx_payment_transactions_status ON payment_transactions(status);
CREATE INDEX idx_payment_transactions_razorpay_order ON payment_transactions(razorpay_order_id);
CREATE INDEX idx_payment_transactions_razorpay_payment ON payment_transactions(razorpay_payment_id);

-- =====================================================
-- 4. WEBHOOK LOGS TABLE (for payment webhooks)
-- =====================================================
CREATE TABLE IF NOT EXISTS webhook_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source VARCHAR(50) NOT NULL, -- 'razorpay', 'other_gateway'
    event_type VARCHAR(100) NOT NULL, -- e.g., 'payment.captured', 'subscription.cancelled'
    payload JSONB NOT NULL,
    signature VARCHAR(500),
    status VARCHAR(20) NOT NULL CHECK (status IN ('received', 'processing', 'processed', 'failed')),
    error_message TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Index for webhook debugging
CREATE INDEX idx_webhook_logs_event_type ON webhook_logs(event_type);
CREATE INDEX idx_webhook_logs_status ON webhook_logs(status);
CREATE INDEX idx_webhook_logs_created_at ON webhook_logs(created_at DESC);

-- =====================================================
-- 5. INSERT DEFAULT SUBSCRIPTION PLANS
-- =====================================================

INSERT INTO subscription_plans (plan_name, plan_code, description, price_monthly, price_yearly, max_branches, max_users, max_products, max_invoices_per_month, features, display_order) VALUES
(
    'Basic',
    'basic',
    'Perfect for small pharmacies and retail stores',
    499.00,
    4999.00,
    1,
    3,
    500,
    200,
    '["Single Branch", "Up to 3 Users", "500 Products", "200 Invoices/Month", "Basic Reports", "Email Support", "Mobile App Access"]'::jsonb,
    1
),
(
    'Professional',
    'professional',
    'Ideal for growing businesses with multiple locations',
    1499.00,
    14999.00,
    5,
    10,
    5000,
    1000,
    '["Up to 5 Branches", "Up to 10 Users", "5000 Products", "1000 Invoices/Month", "Advanced Reports", "Priority Email Support", "Mobile App Access", "API Access", "Custom Branding", "Multi-Branch Management"]'::jsonb,
    2
),
(
    'Enterprise',
    'enterprise',
    'For large organizations requiring unlimited scale',
    4999.00,
    49999.00,
    999,
    999,
    999999,
    999999,
    '["Unlimited Branches", "Unlimited Users", "Unlimited Products", "Unlimited Invoices", "Advanced Analytics & BI", "24/7 Phone Support", "Mobile App Access", "API Access", "Custom Branding", "Multi-Branch Management", "Dedicated Account Manager", "Custom Integrations", "SLA Guarantee"]'::jsonb,
    3
);

-- =====================================================
-- 6. RLS POLICIES FOR SUBSCRIPTION TABLES
-- =====================================================

-- Enable RLS
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_logs ENABLE ROW LEVEL SECURITY;

-- Subscription Plans: Public read (for plan selection page)
CREATE POLICY "Subscription plans are viewable by everyone"
    ON subscription_plans FOR SELECT
    USING (is_active = true);

-- Super admin can manage plans
CREATE POLICY "Super admins can manage subscription plans"
    ON subscription_plans FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
            AND users.role = 'super_admin'
        )
    );

-- Tenant Subscriptions: Tenant can view their own
CREATE POLICY "Tenants can view their own subscriptions"
    ON tenant_subscriptions FOR SELECT
    USING (tenant_id = get_current_tenant_id());

-- Super admin can view all subscriptions
CREATE POLICY "Super admins can view all subscriptions"
    ON tenant_subscriptions FOR SELECT
    USING (is_super_admin());

-- Super admin and system can insert subscriptions
CREATE POLICY "Super admins can manage subscriptions"
    ON tenant_subscriptions FOR ALL
    USING (is_super_admin());

-- Payment Transactions: Tenant can view their own
CREATE POLICY "Tenants can view their own payment transactions"
    ON payment_transactions FOR SELECT
    USING (tenant_id = get_current_tenant_id());

-- Tenant can insert payment transactions (for initiating payments)
CREATE POLICY "Tenants can create payment transactions"
    ON payment_transactions FOR INSERT
    WITH CHECK (tenant_id = get_current_tenant_id());

-- Super admin can view all transactions
CREATE POLICY "Super admins can view all payment transactions"
    ON payment_transactions FOR SELECT
    USING (is_super_admin());

-- Webhook Logs: Only super admin access
CREATE POLICY "Super admins can view webhook logs"
    ON webhook_logs FOR SELECT
    USING (is_super_admin());

CREATE POLICY "System can insert webhook logs"
    ON webhook_logs FOR INSERT
    WITH CHECK (true); -- Service role key will handle this

-- =====================================================
-- 7. FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to update tenant subscription status
CREATE OR REPLACE FUNCTION update_tenant_subscription_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Update tenant's subscription_plan and subscription_status
    UPDATE tenants
    SET 
        subscription_plan = (SELECT plan_code FROM subscription_plans WHERE id = NEW.plan_id),
        subscription_status = NEW.status,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.tenant_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to sync tenant subscription changes
CREATE TRIGGER sync_tenant_subscription_status
AFTER INSERT OR UPDATE ON tenant_subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_tenant_subscription_status();

-- Function to check subscription validity
CREATE OR REPLACE FUNCTION is_subscription_active(tenant_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
    subscription_active BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM tenant_subscriptions
        WHERE tenant_id = tenant_uuid
        AND status = 'active'
        AND end_date > CURRENT_TIMESTAMP
    ) INTO subscription_active;
    
    RETURN subscription_active;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 8. UPDATE TIMESTAMPS TRIGGER
-- =====================================================

CREATE OR REPLACE FUNCTION update_subscription_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_subscription_plans_timestamp
BEFORE UPDATE ON subscription_plans
FOR EACH ROW
EXECUTE FUNCTION update_subscription_timestamp();

CREATE TRIGGER update_tenant_subscriptions_timestamp
BEFORE UPDATE ON tenant_subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_subscription_timestamp();

CREATE TRIGGER update_payment_transactions_timestamp
BEFORE UPDATE ON payment_transactions
FOR EACH ROW
EXECUTE FUNCTION update_subscription_timestamp();

-- =====================================================
-- END OF MIGRATION
-- =====================================================
