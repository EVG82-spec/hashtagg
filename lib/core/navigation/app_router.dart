GoRoute(
path: '/shop/:shopId',
name: 'shopPublic',
builder: (context, state) {
final shopId = state.pathParameters['shopId']!;
return ShopPublicScreen(shopId: shopId);
},
),