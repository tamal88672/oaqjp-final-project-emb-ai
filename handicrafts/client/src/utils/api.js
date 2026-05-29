import axios from 'axios';

const api = axios.create({
  baseURL: '',
});

// Categories
export const getCategories = () => api.get('/api/categories').then(r => r.data);
export const getCategory = (id) => api.get(`/api/categories/${id}`).then(r => r.data);
export const createCategory = (formData) => api.post('/api/categories', formData).then(r => r.data);
export const updateCategory = (id, formData) => api.put(`/api/categories/${id}`, formData).then(r => r.data);
export const deleteCategory = (id) => api.delete(`/api/categories/${id}`).then(r => r.data);

// Products
export const getProducts = (params) => api.get('/api/products', { params }).then(r => r.data);
export const getProduct = (id) => api.get(`/api/products/${id}`).then(r => r.data);
export const createProduct = (formData) => api.post('/api/products', formData).then(r => r.data);
export const updateProduct = (id, formData) => api.put(`/api/products/${id}`, formData).then(r => r.data);
export const deleteProduct = (id) => api.delete(`/api/products/${id}`).then(r => r.data);

// Inventory
export const getInventory = () => api.get('/api/inventory').then(r => r.data);
export const updateInventory = (productId, data) => api.put(`/api/inventory/${productId}`, data).then(r => r.data);
export const getAlerts = () => api.get('/api/inventory/alerts').then(r => r.data);

// Reports
export const getReportSummary = () => api.get('/api/reports/summary').then(r => r.data);
export const getActivityLog = (params) => api.get('/api/reports/activity', { params }).then(r => r.data);
export const getCategoryBreakdown = () => api.get('/api/reports/category-breakdown').then(r => r.data);

// Suppliers
export const getSuppliers = (params) => api.get('/api/suppliers', { params }).then(r => r.data);
export const getSupplier = (id) => api.get(`/api/suppliers/${id}`).then(r => r.data);
export const createSupplier = (data) => api.post('/api/suppliers', data).then(r => r.data);
export const updateSupplier = (id, data) => api.put(`/api/suppliers/${id}`, data).then(r => r.data);
export const deleteSupplier = (id) => api.delete(`/api/suppliers/${id}`).then(r => r.data);

export default api;
