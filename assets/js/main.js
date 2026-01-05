function calculateAge(dob) {
  const birth = new Date(dob);
  if (isNaN(birth)) return 0;
  const diff = Date.now() - birth.getTime();
  const ageDate = new Date(diff);
  return Math.abs(ageDate.getUTCFullYear() - 1970);
}

function handleComplianceForm() {
  const form = document.getElementById('compliance-form');
  const result = document.getElementById('compliance-result');
  if (!form) return;

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const formData = new FormData(form);
    const age = calculateAge(formData.get('dob'));
    const restricted = ['Other'];
    const country = formData.get('country');

    if (age < 18) {
      result.textContent = 'Access denied: age gate failed.';
      result.style.color = '#f87171';
      return;
    }
    if (restricted.includes(country)) {
      result.textContent = 'Unavailable in your region. Geo restriction applied.';
      result.style.color = '#f97316';
      return;
    }

    result.textContent = 'Eligible. Continue to checkout or portal.';
    result.style.color = '#22c55e';
  });
}

function persistSignup(email, creator) {
  const saved = JSON.parse(localStorage.getItem('amplissa_signups') || '[]');
  saved.push({ email, creator, ts: new Date().toISOString() });
  localStorage.setItem('amplissa_signups', JSON.stringify(saved));
}

function handleSignup() {
  const form = document.getElementById('signup-form');
  const result = document.getElementById('signup-result');
  if (!form) return;

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const formData = new FormData(form);
    const email = formData.get('email');
    const creator = formData.get('creator') || 'General';

    if (!email.includes('@')) {
      result.textContent = 'Add a valid email to start the drip.';
      result.style.color = '#f97316';
      return;
    }

    persistSignup(email, creator);
    result.textContent = 'Saved. Drip emails queued automatically.';
    result.style.color = '#22c55e';
    form.reset();
  });
}

function smoothScrolling() {
  document.querySelectorAll('a[href^="#"]').forEach((link) => {
    link.addEventListener('click', (e) => {
      const target = document.querySelector(link.getAttribute('href'));
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth' });
      }
    });
  });
}

function attachCheckoutHandlers() {
  document.querySelectorAll('[data-checkout-button]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const product = btn.getAttribute('data-product') || 'Digital good';
      const price = btn.getAttribute('data-price') || '0.00';
      const notice = document.getElementById('checkout-status');
      if (notice) {
        notice.textContent = `${product} — ready to process $${price} via Stripe or CCBill.`;
      }
    });
  });
}

function init() {
  handleComplianceForm();
  handleSignup();
  smoothScrolling();
  attachCheckoutHandlers();
}

document.addEventListener('DOMContentLoaded', init);
