function showTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
    const targetTabContent = document.getElementById(tabId + 'TabContent') || document.getElementById(tabId + 'Tab');
    if (targetTabContent) {
        targetTabContent.style.display = (tabId === 'report' ? 'flex' : 'block'); 
    }
    
    document.querySelectorAll('.tabs .tab-button').forEach(el => el.classList.remove('active'));
    const btn = document.querySelector(`.tabs .tab-button[onclick*="'${tabId}'"]`);
    if (btn) btn.classList.add('active');

    const isReport = tabId === 'report';
    document.querySelectorAll('.report-action-btn').forEach(btn => {
        btn.style.display = isReport ? 'inline-flex' : 'none';
    });
    
    const configActions = ['generateCutListButton', 'refreshSelectionButton', 'cancelButton'];
    configActions.forEach(id => {
        const btn = document.getElementById(id);
        if (btn) btn.style.display = isReport ? 'none' : 'inline-flex';
    });
}

function refreshConfiguration() {
    callRuby('refresh_config');
}

function showConfigTab() {
    showTab('config');
}

function showReportTab(data) {
    if (typeof receiveData === 'function') {
        receiveData(data);
    }
    
    if (typeof renderReport === 'function') renderReport();
    if (typeof renderDiagrams === 'function') renderDiagrams();
    
    document.getElementById('reportTab').disabled = false;
    showTab('report');
}

function showError(message) {
    alert('Error: ' + message);
}

function showProgressOverlay(message, percentage) {
    }

function updateProgressOverlay(message, percentage) {
    }

function hideProgressOverlay() {
    }

function convertCurrency() {
    const from = document.getElementById('currency_from').value;
    const to = document.getElementById('currency_to').value;
    const amount = parseFloat(document.getElementById('currency_amount').value);
    const resultElement = document.getElementById('conversion_result');
    
    const rates = {
        SAR: { USD: 0.27, EUR: 0.25, SAR: 1.0, AED: 0.98, GBP: 0.22 },
        USD: { SAR: 3.75, EUR: 0.93, USD: 1.0, AED: 3.67, GBP: 0.81 }
    };

    if (!isNaN(amount) && rates[from] && rates[from][to]) {
        const converted = amount * rates[from][to];
        const currencySymbol = to === 'SAR' ? 'ر.س' : to === 'USD' ? '$' : to === 'EUR' ? '€' : to === 'AED' ? 'د.إ' : '£';
        resultElement.innerText = `Result: ${amount} ${from} = ${converted.toFixed(2)} ${to} (${currencySymbol})`;
    } else {
        resultElement.innerText = "Result: Invalid amount or conversion rate missing.";
    }
}

function toggleTreeView() {
    const tree = document.getElementById('treeStructure');
    const search = document.getElementById('treeSearchContainer');
    if (tree && search) {
        if (tree.style.display === 'none' || !tree.style.display) {
            tree.style.display = 'block';
            search.style.display = 'flex';
        } else {
            tree.style.display = 'none';
            search.style.display = 'none';
        }
    }
}

function filterTree() {}
function clearTreeSearch() {}
function expandAll() {}
function collapseAll() {}

document.addEventListener('DOMContentLoaded', () => {
    const reportContent = document.getElementById('reportTabContent');
    if (reportContent) reportContent.style.display = 'none';
});
