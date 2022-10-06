import chalk from 'chalk';

export const action = (message: string) => {
  return console.log(chalk.cyan(message));
};

export const info = (message: string) => {
  return console.log(chalk.dim(message));
};

export const success = (message: string) => {
  return console.log(chalk.green(message));
};

export const warning = (message: string) => {
  return console.log(chalk.yellow(message));
};

export const error = (message: string) => {
  return console.log(chalk.red(message));
};
