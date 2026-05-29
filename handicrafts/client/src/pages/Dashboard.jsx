import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Package, FolderOpen, DollarSign, AlertTriangle, Activity } from 'lucide-react';
import StatsCard from '../components/StatsCard';
import { getReportSummary, getCategoryBreakdown, getActivityLog } from '../utils/api';

export default function Dashboard() {
  const [summary, setSummary] = useState(null);
  const [breakdown, setBreakdown] = useState([]);
  const [activity, setActivity] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      getReportSummary().catch(() => null),
      getCategoryBreakdown().catch(() => []),
      getActivityLog({ limit: 10 }).catch(() => []),
    ]).then(([sum, br, act]) => {
      setSummary(sum);
      setBreakdown(Array.isArray(br) ? br : []);
      setActivity(Array.isArray(act) ? act : []);
      setLoading(false);
    });
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-amber-500 border-t-transparent rounded-full" />
      </div>
    );
  }

  const maxCount = breakdown.length > 0
    ? Math.max(...breakdown.map(b => b.product_count || 0), 1)
    : 1;

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Dashboard</h1>
        <p className="text-sm text-gray-500 mt-1">Welcome to your handicraft trade overview</p>
      </div>

      {/* Stats */}
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

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Category Breakdown */}
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-5">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Category Breakdown</h2>
          {breakdown.length === 0 ? (
            <p className="text-sm text-gray-400 py-4 text-center">No categories yet</p>
          ) : (
            <div className="space-y-3">
              {breakdown.map((cat) => (
                <div key={cat.category_id || cat.name}>
                  <div className="flex justify-between text-sm mb-1">
                    <span className="text-gray-700 font-medium">{cat.name}</span>
                    <span className="text-gray-500">{cat.product_count} products</span>
                  </div>
                  <div className="w-full bg-amber-50 rounded-full h-2.5">
                    <div
                      className="bg-gradient-to-r from-amber-400 to-amber-600 h-2.5 rounded-full transition-all"
                      style={{ width: `${(cat.product_count / maxCount) * 100}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Recent Activity */}
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-5">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Recent Activity</h2>
          {activity.length === 0 ? (
            <p className="text-sm text-gray-400 py-4 text-center">No recent activity</p>
          ) : (
            <div className="space-y-3">
              {activity.map((item, idx) => (
                <div
                  key={item.id || idx}
                  className="flex items-start gap-3 p-3 rounded-lg hover:bg-amber-50/40 transition-colors"
                >
                  <div className="p-1.5 rounded-full bg-amber-100 text-amber-600 mt-0.5">
                    <Activity size={14} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-gray-700">
                      <span className="font-medium">{item.product_name || 'Product'}</span>
                      {' '}&mdash;{' '}
                      <span className={
                        item.action === 'added' ? 'text-green-600' :
                        item.action === 'removed' ? 'text-red-600' :
                        'text-amber-600'
                      }>
                        {item.action || 'updated'}
                      </span>
                      {item.quantity_change != null && (
                        <span className="ml-1 text-gray-500">
                          ({item.quantity_change > 0 ? '+' : ''}{item.quantity_change})
                        </span>
                      )}
                    </p>
                    {item.notes && (
                      <p className="text-xs text-gray-400 truncate">{item.notes}</p>
                    )}
                    <p className="text-xs text-gray-400 mt-0.5">
                      {item.created_at ? new Date(item.created_at).toLocaleString() : ''}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
