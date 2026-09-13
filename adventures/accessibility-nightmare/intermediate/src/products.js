export const PRODUCTS = [
    {
        slug: 'smart-watch',
        name: 'Smart watch',
        description: 'Track your day with a clean, lightweight design.',
        image: '/images/watch.svg',
        imageAlt: 'A smart watch with a dark strap and a round face.',
        sizes: ['38 mm', '42 mm', '46 mm'],
    },
    {
        slug: 'wireless-headphones',
        name: 'Wireless headphones',
        description: 'Comfortable sound for work, travel, and exercise.',
        image: '/images/headphones.svg',
        imageAlt: 'Over-ear wireless headphones with padded cups.',
        sizes: ['Small', 'Medium', 'Large'],
    },
    {
        slug: 'running-shoes',
        name: 'Running shoes',
        description: 'Flexible everyday shoes made for active routines.',
        image: '/images/shoes.svg',
        imageAlt: 'A running shoe in profile, with a ridged sole.',
        sizes: ['41', '42', '43'],
    },
];

export function findProduct(slug) {
    return PRODUCTS.find((product) => product.slug === slug);
}
