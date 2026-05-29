import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Plus, Search, Edit2, Trash2, Truck, Phone, Mail } from 'lucide-react';
import Modal from '../components/Modal';
import { getSuppliers, deleteSupplier } from '../utils/api';

export default function SupplierList() {
  const [suppliers, setSuppliers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [deleteModal, setDeleteModal] = useState(false);
  const [deleting, setDeleting] = useState(null);

  const fetchSuppliers = (searchQuery) => {
    setLoading(true);
    const params = {};
    if (searchQuery) params.search = searchQuery;
    getSuppliers(params)
      .then((data) => setSuppliers(Array.isArray(data) ? data : []))
      .catch(() => setSuppliers([]))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchSuppliers(search);
  }, [search]);

  const handleDelete = async () => {
    if (!deleting) return;
    try {
      await deleteSupplier(deleting.id);
      setDeleteModal(false);
      setDeleting(null);
      fetchSuppliers(search);
    } catch (err) {
      alert('Failed to delete supplier');
    }
  };

  return (
    <div>
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-800">Suppliers</h1>
          <p className="text-sm text-gray-500 mt-1">Manage your artisan and supplier network</p>
        </div>
        <Link
          to="/suppliers/new"
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-amber-600 text-white rounded-lg hover:bg-amber-700 transition-colors text-sm font-medium"
        >
          <Plus size={18} />
          Add Supplier
        </Link>
      </div>

      {/* Search */}
      <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4 mb-6">
        <div className="relative">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search by name, city, or specialization..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-amber-300"
          />
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center h-48">
          <div className="animate-spin w-8 h-8 border-4 border-amber-500 border-t-transparent rounded-full" />
        </div>
      ) : suppliers.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-xl border border-gray-100 shadow-sm">
          <Truck size={48} className="mx-auto text-gray-300 mb-3" />
          <p className="text-gray-500">No suppliers found</p>
          <Link
            to="/suppliers/new"
            className="inline-block mt-3 text-sm text-amber-600 hover:text-amber-700 font-medium"
          >
            Add your first supplier
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {suppliers.map((supplier) => (
            <div
              key={supplier.id}
              className="bg-white rounded-xl border border-gray-100 shadow-sm p-5 hover:shadow-md transition-shadow"
            >
              <div className="flex items-start justify-between mb-3">
                <div>
                  <h3 className="font-semibold text-gray-800">{supplier.name}</h3>
                  {supplier.contact_person && (
                    <p className="text-xs text-gray-400 mt-0.5">{supplier.contact_person}</p>
                  )}
                </div>
                <div className="flex items-center gap-1">
                  <Link
                    to={`/suppliers/${supplier.id}/edit`}
                    className="p-1.5 rounded-lg hover:bg-amber-50 text-gray-400 hover:text-amber-600 transition-colors"
                  >
                    <Edit2 size={14} />
                  </Link>
                  <button
                    onClick={() => { setDeleting(supplier); setDeleteModal(true); }}
                    className="p-1.5 rounded-lg hover:bg-red-50 text-gray-400 hover:text-red-600 transition-colors"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>

              <div className="space-y-2">
                {supplier.specialization && (
                  <div className="inline-block text-xs px-2 py-0.5 bg-amber-50 text-amber-700 rounded-full font-medium">
                    {supplier.specialization}
                  </div>
                )}
                {(supplier.city || supplier.state) && (
                  <p className="text-sm text-gray-500">
                    {[supplier.city, supplier.state].filter(Boolean).join(', ')}
                  </p>
                )}
                {supplier.phone && (
                  <div className="flex items-center gap-2 text-sm text-gray-500">
                    <Phone size={13} className="text-gray-400" />
                    {supplier.phone}
                  </div>
                )}
                {supplier.email && (
                  <div className="flex items-center gap-2 text-sm text-gray-500">
                    <Mail size={13} className="text-gray-400" />
                    {supplier.email}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Delete Confirmation */}
      <Modal
        isOpen={deleteModal}
        onClose={() => setDeleteModal(false)}
        title="Delete Supplier"
      >
        <p className="text-sm text-gray-600 mb-5">
          Are you sure you want to delete <span className="font-semibold">{deleting?.name}</span>?
          This action cannot be undone.
        </p>
        <div className="flex justify-end gap-3">
          <button
            onClick={() => setDeleteModal(false)}
            className="px-4 py-2 text-sm text-gray-600 hover:text-gray-800"
          >
            Cancel
          </button>
          <button
            onClick={handleDelete}
            className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors text-sm font-medium"
          >
            Delete
          </button>
        </div>
      </Modal>
    </div>
  );
}
