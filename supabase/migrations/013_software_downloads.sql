-- =====================================================
-- Software Downloads & Versioning
-- =====================================================
-- This migration creates tables for managing software downloads

-- =====================================================
-- 1. SOFTWARE VERSIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS software_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version_number VARCHAR(50) NOT NULL UNIQUE, -- e.g., "1.0.0", "1.0.1"
    version_name VARCHAR(100), -- e.g., "Spring Release"
    release_notes TEXT,
    release_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_latest BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    min_os_version JSONB, -- {"windows": "10", "mac": "10.15", "linux": "Ubuntu 20.04"}
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 2. SOFTWARE DOWNLOADS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS software_downloads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    version_id UUID NOT NULL REFERENCES software_versions(id) ON DELETE CASCADE,
    platform VARCHAR(50) NOT NULL CHECK (platform IN ('windows', 'mac', 'linux')),
    architecture VARCHAR(20) CHECK (architecture IN ('x64', 'arm64', 'x86')),
    file_name VARCHAR(255) NOT NULL,
    file_size_bytes BIGINT,
    download_url TEXT NOT NULL,
    checksum_sha256 VARCHAR(64),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(version_id, platform, architecture)
);

-- =====================================================
-- 3. DOWNLOAD TRACKING TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS download_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    download_id UUID REFERENCES software_downloads(id) ON DELETE SET NULL,
    version_id UUID REFERENCES software_versions(id) ON DELETE SET NULL,
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    platform VARCHAR(50),
    downloaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_download_logs_version ON download_logs(version_id);
CREATE INDEX idx_download_logs_tenant ON download_logs(tenant_id);
CREATE INDEX idx_download_logs_downloaded_at ON download_logs(downloaded_at DESC);

-- =====================================================
-- 4. RLS POLICIES
-- =====================================================

-- Software Versions: Public read for active versions
ALTER TABLE software_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Software versions are viewable by everyone"
    ON software_versions FOR SELECT
    USING (is_active = true);

CREATE POLICY "Super admins can manage software versions"
    ON software_versions FOR ALL
    USING (is_super_admin());

-- Software Downloads: Public read for active downloads
ALTER TABLE software_downloads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Software downloads are viewable by everyone"
    ON software_downloads FOR SELECT
    USING (is_active = true);

CREATE POLICY "Super admins can manage software downloads"
    ON software_downloads FOR ALL
    USING (is_super_admin());

-- Download Logs: Users can insert their own downloads
ALTER TABLE download_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can log their own downloads"
    ON download_logs FOR INSERT
    WITH CHECK (true); -- Service role will handle this

CREATE POLICY "Users can view their own download history"
    ON download_logs FOR SELECT
    USING (
        user_id = auth.uid() OR
        tenant_id = get_current_tenant_id()
    );

CREATE POLICY "Super admins can view all download logs"
    ON download_logs FOR SELECT
    USING (is_super_admin());

-- =====================================================
-- 5. INSERT INITIAL SOFTWARE VERSION
-- =====================================================

INSERT INTO software_versions (version_number, version_name, release_notes, release_date, is_latest, min_os_version) VALUES
(
    '1.0.0',
    'Initial Release',
    'First public release of LifeSprout pharmacy management system.

Features:
- Multi-tenant POS billing
- Inventory management
- Customer management
- Batch tracking and expiry alerts
- Schedule H/X drug logging
- GST-compliant invoicing
- Offline support
- Real-time sync',
    CURRENT_TIMESTAMP,
    true,
    '{"windows": "10", "mac": "10.15", "linux": "Ubuntu 20.04"}'::jsonb
);

-- Insert download links (placeholder URLs - replace with actual storage URLs)
INSERT INTO software_downloads (version_id, platform, architecture, file_name, file_size_bytes, download_url, checksum_sha256) VALUES
(
    (SELECT id FROM software_versions WHERE version_number = '1.0.0'),
    'windows',
    'x64',
    'LifeSprout-1.0.0-Windows-x64.exe',
    150000000,
    'https://storage.lifesprout.com/releases/v1.0.0/LifeSprout-1.0.0-Windows-x64.exe',
    'placeholder_checksum_windows'
),
(
    (SELECT id FROM software_versions WHERE version_number = '1.0.0'),
    'mac',
    'x64',
    'LifeSprout-1.0.0-macOS-x64.dmg',
    120000000,
    'https://storage.lifesprout.com/releases/v1.0.0/LifeSprout-1.0.0-macOS-x64.dmg',
    'placeholder_checksum_mac_x64'
),
(
    (SELECT id FROM software_versions WHERE version_number = '1.0.0'),
    'mac',
    'arm64',
    'LifeSprout-1.0.0-macOS-arm64.dmg',
    120000000,
    'https://storage.lifesprout.com/releases/v1.0.0/LifeSprout-1.0.0-macOS-arm64.dmg',
    'placeholder_checksum_mac_arm64'
),
(
    (SELECT id FROM software_versions WHERE version_number = '1.0.0'),
    'linux',
    'x64',
    'LifeSprout-1.0.0-Linux-x64.AppImage',
    130000000,
    'https://storage.lifesprout.com/releases/v1.0.0/LifeSprout-1.0.0-Linux-x64.AppImage',
    'placeholder_checksum_linux'
);

-- =====================================================
-- 6. UPDATE TIMESTAMPS TRIGGER
-- =====================================================

CREATE TRIGGER update_software_versions_timestamp
BEFORE UPDATE ON software_versions
FOR EACH ROW
EXECUTE FUNCTION update_subscription_timestamp();

CREATE TRIGGER update_software_downloads_timestamp
BEFORE UPDATE ON software_downloads
FOR EACH ROW
EXECUTE FUNCTION update_subscription_timestamp();

-- =====================================================
-- END OF MIGRATION
-- =====================================================
