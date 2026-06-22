# Pinia & Vue Router Reference

## Pinia Store Patterns

### Setup Store (Preferred)

```typescript
// stores/order.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { orderApi } from '@/api/order'
import type { Order } from '@/types'

export const useOrderStore = defineStore('order', () => {
  // State
  const orders = ref<Order[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const pendingOrders = computed(() =>
    orders.value.filter(o => o.status === 'pending')
  )
  const orderCount = computed(() => orders.value.length)

  // Actions
  async function fetchOrders() {
    loading.value = true
    error.value = null
    try {
      orders.value = await orderApi.getAll()
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch'
    } finally {
      loading.value = false
    }
  }

  async function createOrder(data: CreateOrderRequest): Promise<Order> {
    const order = await orderApi.create(data)
    orders.value.push(order)
    return order
  }

  function $reset() {
    orders.value = []
    loading.value = false
    error.value = null
  }

  return { orders, loading, error, pendingOrders, orderCount, fetchOrders, createOrder, $reset }
})
```

### Store Rules

- One store per domain (not per component).
- Use Setup Stores (function syntax) for better TypeScript support and composability.
- Always expose a `$reset()` method for testing.
- Keep API calls in stores, not in components.
- Don't access stores from other stores in circular ways.
- Use `storeToRefs()` when destructuring reactive state from store.

## Vue Router

### Route Configuration

```typescript
// router/index.ts
import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: () => import('@/views/HomeView.vue'),
    },
    {
      path: '/orders',
      name: 'orders',
      component: () => import('@/views/OrderList.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/orders/:id',
      name: 'order-detail',
      component: () => import('@/views/OrderDetail.vue'),
      props: true,
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('@/views/NotFound.vue'),
    },
  ],
})

// Navigation guard
router.beforeEach((to) => {
  if (to.meta.requiresAuth && !isAuthenticated()) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
})

export default router
```

### Router Rules

- Always use lazy loading (`() => import(...)`) for route components.
- Pass route params as props (`props: true`) instead of accessing `$route` in components.
- Use named routes for navigation, not hardcoded paths.
- Define `meta` types for route metadata (auth, roles, breadcrumbs).
- Handle 404 with a catch-all route.
- Keep navigation guards in the router file, not scattered in components.
