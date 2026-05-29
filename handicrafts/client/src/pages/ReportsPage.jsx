import { useState, useEffect } from 'react';
import { Package, FolderOpen, DollarSign, AlertTriangle } from 'lucide-react';
import StatsCard from '../components/StatsCard';
import { getReportSummary, getActivityLog, getCategoryBreakdown } from '../utils/api';

export default function ReportsPage() {
  const [summary, setSummary] = useState(null);
  const [activity, setActivity] = useState([]);
  const [breakdown, setBreakdown] = useState([]);
  const [loading, setLoading] = useState(true);
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');

  const fetchData = () => {
    setLoading(true);
    const actParams = {};
    if (dateFrom) actParams.from = dateFrom;
    if (dateTo) actParams.to = dateTo;

    Promise.all([
      getReportSummary().catch(() => null),
      getActivityLog(actParams).catch(() => []),
      getCategoryBreakdown().catch(() => []),
    ]).then(([sum, act, br]) => {
      setSummary(sum);
      setActivity(Array.isArray(act) ? act : []);
      setBreakdown(Array.isArray(br) ? br : []);
      setLoading(false);
    });
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleFilter = () => {
    fetchData();
  };

  const maxCount = breakdown.length > 0
    ? Math.max(...breakdown.map(b => b.product_count || 0), 1)
    : 1;

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-amber-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Reports</h1>
        <p className="text-sm text-gray-500 mt-1">Analytics and activity overview</p>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatsCard
          icon={Package}
          label="Total Products"
          value={summary?.total_products ?? 0}
          color="amber"
        />
        <StatsCard
          icon={FolderOpen}
          label="Total Categories"
          value={summary?.total_categories ?? 0}
          color="blue"
        />
        <StatsCard
          icon={DollarSign}
          label="Inventory Value (USD)"
          value={`$${(summary?.total_inventory_value ?? 0).toLocaleString()}`}
          color="green"
        />
        <StatsCard
          icon={AlertTriangle}
          label="Low Stock Alerts"
          value={summary?.low_stock_alerts ?? 0}
          color="red"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Activity Log */}
        <div className="lg:col-span-2 bg-white rounded-xl border border-gray-100 shadow-sm">
          <div className="p-5 border-b border-gray-100">
            <h2 className="text-lg font-semibold text-gray-800 mb-3">Activity Log</h2>
            <div className="flex flex-col sm:flex-row gap-3">
              <div>
                <label className="block text-xs text-gray-500 mb-1">From</label>
                <input
                  type="date"
                  value={dateFrom}
                  onChange={(e) => setDateFrom(e.target.value)}
                  className="px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-300"
                />
              </div>
              <div>
                <label className="block text-xs text-gray-500 mb-1">To</label>
                <input
                  type="date"
                  value={dateTo}
                  onChange={(e) => setDateTo(e.target.value)}
                  className="px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-300"
                />
              </div>
              <div className="flex items-end">
                <button
                  onClick={handleFilter}
                  className="px-4 py-1.5 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition-colors text-sm font-medium"
                >
                  Filter
                </button>
              </div>
            </div>
          </div>

          <div className="overflow-x-auto">
            {activity.length === 0 ? (
              <p className="text-sm text-gray-400 py-8 text-center">No activity recorded</p>
            ) : (
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-100 text-left">
                    <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase">Date/Time</th>
                    <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase">Product</th>
                    <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase">Action</th>
                    <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase text-center">Qty Change</th>
                    <th className="px-4 py-3 text-xs font-medium text-gray-500 uppercase hidden md:table-cell">Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {activity.map((item, idx) => (
                    <tr key={item.id || idx} className="border-b border-gray-50 hover:bg-amber-50/30">
                      <td className="px-4 py-3 text-xs text-gray-500 whitespace-nowrap">
                        {item.created_at ? new Date(item.created_at).toLocaleString() : '-'}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-700 font-medium">
                        {item.product_name || '-'}
                      </td>
                      <td className="px-4 py-3">
                        <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                          item.action === 'added' ? 'bg-green-100 text-green-700' :
                          item.action === 'removed' ? 'bg-red-100 text-red-700' :
                          'bg-amber-100 text-amber-700'
                        }`}>
                          {item.action || 'adjusted'}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm text-center">
                        {item.quantity_change != null && (
                          <span className={item.quantity_change > 0 ? 'text-green-600 font-medium' : item.quantity_change < 0 ? 'text-red-600 font-medium' : 'text-gray-500'}>
                            {item.quantity_change > 0 ? '+' : ''}{item.quantity_change}
                          </span>
                        )}
                      </td>
                      <td className="px-4 py-3 text-xs text-gray-400 hidden md:table-cell max-w-xs truncate">
                        {item.notes || '-'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>

        {/* Category Breakdown */}
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-5">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Category Breakdown</h2>
          {breakdown.length === 0 ? (
            <p className="text-sm text-gray-400 py-4 text-center">No categories yet</p>
          ) : (
            <div className="space-y-4">
              {breakdown.map((cat) => (
                <div key={cat.category_id || cat.name}>
                  <div className="flex justify-between text-sm mb-1">
                    <span className="text-gray-700 font-medium">{cat.name}</span>
                    <span className="text-gray-500">{cat.product_count}</span>
                  </div>
                  <div className="w-full bg-amber-50 rounded-full h-3">
                    <div
                      className="bg-gradient-to-r from-amber-400 to-amber-600 h-3 rounded-full transition-all"
                      style={{ width: `${(cat.product_count / maxCount) * 100}%` }}
                    />
                  </div>
                  {cat.total_value != null && (
                    <p className="text-xs text-gray-400 mt-0.5">
                      Value: ${Number(cat.total_value).toLocaleString()}
                    </p>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
