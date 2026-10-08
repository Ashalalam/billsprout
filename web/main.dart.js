// Placeholder for Flutter main.dart.js
console.log('BillSprout ERP - Direct Static Deployment');

// Simple fallback if Flutter files are not available
if (!window.flutter) {
  document.body.innerHTML = `
    <div style="
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      background: #182B68;
      color: white;
      font-family: -apple-system, sans-serif;
      flex-direction: column;
      text-align: center;
      padding: 20px;
    ">
      <div style="
        background: white;
        color: #182B68;
        padding: 20px;
        border-radius: 12px;
        margin-bottom: 20px;
        font-size: 48px;
        font-weight: bold;
      ">BS</div>
      <h1>BillSprout ERP</h1>
      <p>Flutter application files are being prepared for deployment...</p>
      <p style="font-size: 14px; opacity: 0.7; margin-top: 20px;">
        This is a temporary message. Your full Flutter application will be available once the build process is completed.
      </p>
    </div>
  `;
}